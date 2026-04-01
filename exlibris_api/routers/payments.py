from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException

from core.database import get_db_connection
from dependencies.auth import get_current_user_id
from schemas.exchange import ExchangeOut, row_to_exchange
from schemas.payment import (
    ExchangePaymentCreate,
    ExchangePaymentOut,
    row_to_exchange_payment,
)


router = APIRouter(tags=["payments"])


def utc_now_naive() -> datetime:
    """
    Retourne un datetime UTC naïf.
    Compatible avec les DATETIME MariaDB renvoyés par pymysql.
    """
    return datetime.now(UTC).replace(tzinfo=None)


def _get_exchange_for_update(cur, exchange_id: int):
    cur.execute(
        """
        SELECT
            e.id_echange,
            e.demandeur_id,
            e.destinataire_id,
            e.livre_demandeur_isbn,
            l1.titre,
            e.livre_destinataire_isbn,
            l2.titre,
            e.statut,
            e.date_creation,
            e.date_derniere_maj
        FROM Echange e
        LEFT JOIN Livre l1 ON e.livre_demandeur_isbn = l1.isbn
        LEFT JOIN Livre l2 ON e.livre_destinataire_isbn = l2.isbn
        WHERE e.id_echange = %s
        """,
        (exchange_id,),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Échange introuvable")
    return row


@router.post("/exchanges/{exchange_id}/payment", response_model=ExchangePaymentOut)
def create_exchange_payment(
    exchange_id: int,
    body: ExchangePaymentCreate,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        exchange = _get_exchange_for_update(cur, exchange_id)

        demandeur_id = exchange[1]
        statut = exchange[7]

        if current_user_id != demandeur_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le demandeur peut initier le paiement.",
            )

        if statut != "demande_acceptee":
            raise HTTPException(
                status_code=400,
                detail="Le paiement n'est possible qu'après acceptation de l'échange.",
            )

        if body.montant <= 0:
            raise HTTPException(
                status_code=400,
                detail="Le montant doit être supérieur à 0.",
            )

        cur.execute(
            """
            SELECT id_paiement
            FROM PaiementEchange
            WHERE echange_id = %s AND statut IN ('en_attente', 'paye')
            LIMIT 1
            """,
            (exchange_id,),
        )
        existing = cur.fetchone()
        if existing:
            raise HTTPException(
                status_code=400,
                detail="Un paiement existe déjà pour cet échange.",
            )

        cur.execute(
            """
            INSERT INTO PaiementEchange (
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut
            )
            VALUES (%s, %s, %s, 'EUR', 'sandbox', 'en_attente')
            """,
            (exchange_id, current_user_id, body.montant),
        )
        paiement_id = cur.lastrowid

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'paiement_en_attente'
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        cur.execute(
            """
            SELECT
                id_paiement,
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut,
                date_creation,
                date_paiement,
                date_derniere_maj
            FROM PaiementEchange
            WHERE id_paiement = %s
            """,
            (paiement_id,),
        )
        row = cur.fetchone()

        conn.commit()

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return row_to_exchange_payment(row)


@router.get("/exchanges/{exchange_id}/payment", response_model=ExchangePaymentOut)
def get_exchange_payment(
    exchange_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        exchange = _get_exchange_for_update(cur, exchange_id)
        demandeur_id = exchange[1]
        destinataire_id = exchange[2]

        if current_user_id not in {demandeur_id, destinataire_id}:
            raise HTTPException(status_code=403, detail="Non autorisé")

        cur.execute(
            """
            SELECT
                id_paiement,
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut,
                date_creation,
                date_paiement,
                date_derniere_maj
            FROM PaiementEchange
            WHERE echange_id = %s
            ORDER BY date_creation DESC
            LIMIT 1
            """,
            (exchange_id,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(
                status_code=404,
                detail="Aucun paiement trouvé pour cet échange",
            )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return row_to_exchange_payment(row)


@router.post("/payments/{payment_id}/sandbox-pay", response_model=ExchangePaymentOut)
def sandbox_pay_payment(
    payment_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT
                id_paiement,
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut,
                date_creation,
                date_paiement,
                date_derniere_maj
            FROM PaiementEchange
            WHERE id_paiement = %s
            """,
            (payment_id,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Paiement introuvable")

        payeur_id = row[2]
        echange_id = row[1]
        statut = row[6]

        if current_user_id != payeur_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le payeur peut simuler ce paiement.",
            )

        if statut != "en_attente":
            raise HTTPException(
                status_code=400,
                detail="Ce paiement n'est pas en attente.",
            )

        cur.execute(
            """
            UPDATE PaiementEchange
            SET statut = 'paye',
                date_paiement = %s
            WHERE id_paiement = %s
            """,
            (utc_now_naive(), payment_id),
        )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'paiement_effectue'
            WHERE id_echange = %s
            """,
            (echange_id,),
        )

        cur.execute(
            """
            SELECT
                id_paiement,
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut,
                date_creation,
                date_paiement,
                date_derniere_maj
            FROM PaiementEchange
            WHERE id_paiement = %s
            """,
            (payment_id,),
        )
        updated_row = cur.fetchone()

        conn.commit()

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return row_to_exchange_payment(updated_row)


@router.post("/exchanges/{exchange_id}/confirm-shipment", response_model=ExchangeOut)
def confirm_exchange_shipment(
    exchange_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)

        demandeur_id = row[1]
        livre_demandeur_isbn = row[3]
        statut = row[7]

        if current_user_id != demandeur_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le demandeur peut confirmer l'expédition.",
            )

        if statut != "paiement_effectue":
            raise HTTPException(
                status_code=400,
                detail="L'expédition n'est possible qu'après paiement.",
            )

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (demandeur_id, livre_demandeur_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le demandeur ne possède plus le livre à expédier.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'expedition_confirmee'
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        row = _get_exchange_for_update(cur, exchange_id)
        conn.commit()

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return row_to_exchange(row)


@router.post("/exchanges/{exchange_id}/confirm-reception", response_model=ExchangeOut)
def confirm_exchange_reception(
    exchange_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)

        demandeur_id = row[1]
        destinataire_id = row[2]
        livre_demandeur_isbn = row[3]
        livre_destinataire_isbn = row[5]
        statut = row[7]

        if current_user_id != destinataire_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le destinataire peut confirmer la réception.",
            )

        if statut != "expedition_confirmee":
            raise HTTPException(
                status_code=400,
                detail="La réception n'est possible qu'après expédition confirmée.",
            )

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (demandeur_id, livre_demandeur_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le demandeur ne possède plus son livre.",
            )

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (destinataire_id, livre_destinataire_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le destinataire ne possède plus son livre.",
            )

        cur.execute(
            """
            DELETE FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (demandeur_id, livre_demandeur_isbn),
        )

        cur.execute(
            """
            DELETE FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (destinataire_id, livre_destinataire_isbn),
        )

        cur.execute(
            """
            INSERT INTO Collection (utilisateur_id, livre_isbn)
            VALUES (%s, %s)
            """,
            (destinataire_id, livre_demandeur_isbn),
        )

        cur.execute(
            """
            INSERT INTO Collection (utilisateur_id, livre_isbn)
            VALUES (%s, %s)
            """,
            (demandeur_id, livre_destinataire_isbn),
        )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'termine'
            WHERE id_echange = %s
            """,
            (exchange_id,),
        )

        cur.execute(
            """
            UPDATE PaiementEchange
            SET statut = 'libere'
            WHERE echange_id = %s AND statut = 'paye'
            """,
            (exchange_id,),
        )

        row = _get_exchange_for_update(cur, exchange_id)
        conn.commit()

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return row_to_exchange(row)


@router.get("/me/payments", response_model=list[ExchangePaymentOut])
def get_my_payments(current_user_id: int = Depends(get_current_user_id)):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT
                id_paiement,
                echange_id,
                payeur_id,
                montant,
                devise,
                provider,
                statut,
                date_creation,
                date_paiement,
                date_derniere_maj
            FROM PaiementEchange
            WHERE payeur_id = %s
            ORDER BY date_creation DESC
            """,
            (current_user_id,),
        )
        rows = cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    return [row_to_exchange_payment(row) for row in rows]