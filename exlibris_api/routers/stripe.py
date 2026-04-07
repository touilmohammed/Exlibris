import stripe
from fastapi import APIRouter, Depends, HTTPException, Request

from core.config import STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, FRONTEND_URL
from core.database import get_db_connection
from dependencies.auth import get_current_user_id
from services.stripe_service import create_checkout_session

router = APIRouter(tags=["stripe"])

stripe.api_key = STRIPE_SECRET_KEY


@router.post("/exchanges/{exchange_id}/checkout-session")
def create_exchange_checkout_session(
    exchange_id: int,
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
                e.statut
            FROM Echange e
            WHERE e.id_echange = %s
            """,
            (exchange_id,),
        )
        exchange = cur.fetchone()

        if not exchange:
            raise HTTPException(status_code=404, detail="Échange introuvable")

        _, demandeur_id, _, exchange_status = exchange

        if current_user_id != demandeur_id:
            raise HTTPException(status_code=403, detail="Seul le demandeur peut payer cet échange.")

        if exchange_status not in {"demande_acceptee", "paiement_en_attente"}:
            raise HTTPException(
                status_code=400,
                detail="Le paiement Stripe n'est possible qu'après acceptation de l'échange.",
            )

        cur.execute(
            """
            SELECT
                id_paiement,
                montant,
                statut
            FROM PaiementEchange
            WHERE echange_id = %s
            ORDER BY date_creation DESC
            LIMIT 1
            """,
            (exchange_id,),
        )
        payment = cur.fetchone()

        if not payment:
            raise HTTPException(status_code=404, detail="Paiement introuvable pour cet échange")

        payment_id, montant, payment_status = payment

        if payment_status not in {"en_attente", "echoue"}:
            raise HTTPException(
                status_code=400,
                detail="Ce paiement n'est pas dans un état compatible avec Stripe Checkout.",
            )

        amount_cents = int(round(float(montant) * 100))

        session = create_checkout_session(
            amount_cents=amount_cents,
            success_url=f"{FRONTEND_URL}/payment/success?exchange_id={exchange_id}",
            cancel_url=f"{FRONTEND_URL}/payment/cancel?exchange_id={exchange_id}",
            exchange_id=exchange_id,
            payment_id=payment_id,
            user_id=current_user_id,
        )

        cur.execute(
            """
            UPDATE PaiementEchange
            SET stripe_checkout_session_id = %s
            WHERE id_paiement = %s
            """,
            (session.id, payment_id),
        )
        conn.commit()

        return {
            "checkout_url": session.url,
            "checkout_session_id": session.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur Stripe: {e}")
    finally:
        conn.close()


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request):
    payload = await request.body()
    sig_header = request.headers.get("Stripe-Signature")

    try:
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=sig_header,
            secret=STRIPE_WEBHOOK_SECRET,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Payload webhook invalide")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Signature webhook invalide")

    event_type = event["type"]

    if event_type == "checkout.session.completed":
        session = event["data"]["object"]

        checkout_session_id = session["id"]
        payment_intent_id = session["payment_intent"]
        payment_status = session["payment_status"]

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute(
                """
                SELECT id_paiement, echange_id, statut
                FROM PaiementEchange
                WHERE stripe_checkout_session_id = %s
                LIMIT 1
                """,
                (checkout_session_id,),
            )
            row = cur.fetchone()

            if not row:
                return {"received": True, "ignored": "paiement_non_trouve"}

            payment_id, exchange_id, statut = row

            if statut == "en_attente" and payment_status == "paid":
                cur.execute(
                    """
                    UPDATE PaiementEchange
                    SET
                        statut = 'paye',
                        provider = 'stripe',
                        stripe_payment_intent_id = %s,
                        stripe_payment_status = %s,
                        date_paiement = NOW()
                    WHERE id_paiement = %s
                    """,
                    (payment_intent_id, payment_status, payment_id),
                )

                cur.execute(
                    """
                    UPDATE Echange
                    SET statut = 'paiement_effectue'
                    WHERE id_echange = %s
                    """,
                    (exchange_id,),
                )

                conn.commit()

        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=f"Erreur webhook Stripe: {e}")
        finally:
            conn.close()

    return {"received": True}