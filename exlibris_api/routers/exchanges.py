from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from core.database import get_db_connection
from dependencies.auth import get_current_user_id
from schemas.exchange import ExchangeCreate, ExchangeOut, row_to_exchange


router = APIRouter(tags=["exchanges"])


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


@router.post("/exchanges", response_model=ExchangeOut)
def create_exchange(
    body: ExchangeCreate,
    current_user_id: int = Depends(get_current_user_id),
):
    if body.destinataire_id == current_user_id:
        raise HTTPException(
            status_code=400,
            detail="On ne peut pas créer un échange avec soi-même.",
        )

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            "SELECT 1 FROM Utilisateur WHERE id_utilisateur = %s",
            (body.destinataire_id,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Destinataire introuvable")

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (current_user_id, body.livre_demandeur_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Vous ne possédez pas le livre proposé à l'échange.",
            )

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (body.destinataire_id, body.livre_destinataire_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le destinataire ne possède pas le livre demandé.",
            )

        cur.execute(
            "SELECT 1 FROM Livre WHERE isbn = %s",
            (body.livre_demandeur_isbn,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Livre du demandeur introuvable")

        cur.execute(
            "SELECT 1 FROM Livre WHERE isbn = %s",
            (body.livre_destinataire_isbn,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Livre du destinataire introuvable")

        cur.execute(
            """
            INSERT INTO Echange (
                demandeur_id,
                destinataire_id,
                livre_demandeur_isbn,
                livre_destinataire_isbn,
                statut
            )
            VALUES (%s, %s, %s, %s, 'demande_envoyee')
            """,
            (
                current_user_id,
                body.destinataire_id,
                body.livre_demandeur_isbn,
                body.livre_destinataire_isbn,
            ),
        )
        exchange_id = cur.lastrowid

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


@router.get("/me/exchanges", response_model=list[ExchangeOut])
def list_my_exchanges(
    role: Optional[str] = Query(default=None),
    statut: Optional[str] = Query(default=None),
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
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
            WHERE e.demandeur_id = %s OR e.destinataire_id = %s
            ORDER BY e.date_creation DESC
            """,
            (current_user_id, current_user_id),
        )
        rows = cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur MariaDB: {e}")
    finally:
        conn.close()

    results = []
    for row in rows:
        exc = row_to_exchange(row)
        is_demandeur = exc.demandeur_id == current_user_id
        is_destinataire = exc.destinataire_id == current_user_id

        if role == "demandeur" and not is_demandeur:
            continue
        if role == "destinataire" and not is_destinataire:
            continue
        if statut and exc.statut != statut:
            continue

        results.append(exc)

    return results


@router.post("/exchanges/{exchange_id}/accept", response_model=ExchangeOut)
def accept_exchange(
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
                detail="Seul le destinataire peut accepter cet échange.",
            )

        if statut != "demande_envoyee":
            raise HTTPException(
                status_code=400,
                detail="Statut invalide pour acceptation.",
            )

        cur.execute(
            """
            SELECT 1 FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (demandeur_id, livre_demandeur_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le demandeur ne possède plus le livre proposé.",
            )

        cur.execute(
            """
            SELECT 1 FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (destinataire_id, livre_destinataire_isbn),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Le destinataire ne possède plus le livre demandé.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'demande_acceptee'
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


@router.post("/exchanges/{exchange_id}/refuse", response_model=ExchangeOut)
def refuse_exchange(
    exchange_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)

        destinataire_id = row[2]
        statut = row[7]

        if current_user_id != destinataire_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le destinataire peut refuser cet échange.",
            )

        if statut != "demande_envoyee":
            raise HTTPException(
                status_code=400,
                detail="Statut invalide pour refus.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'demande_refusee'
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


@router.post("/exchanges/{exchange_id}/cancel", response_model=ExchangeOut)
def cancel_exchange(
    exchange_id: int,
    current_user_id: int = Depends(get_current_user_id),
):
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        row = _get_exchange_for_update(cur, exchange_id)

        demandeur_id = row[1]
        statut = row[7]

        if current_user_id != demandeur_id:
            raise HTTPException(
                status_code=403,
                detail="Seul le demandeur peut annuler cet échange.",
            )

        if statut not in {"demande_envoyee", "demande_acceptee"}:
            raise HTTPException(
                status_code=400,
                detail="Statut invalide pour annulation.",
            )

        cur.execute(
            """
            UPDATE Echange
            SET statut = 'annule'
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