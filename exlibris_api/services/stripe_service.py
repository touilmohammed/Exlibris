import stripe

from core.config import STRIPE_SECRET_KEY

stripe.api_key = STRIPE_SECRET_KEY


def create_checkout_session(
    *,
    amount_cents: int,
    success_url: str,
    cancel_url: str,
    exchange_id: int,
    payment_id: int,
    user_id: int,
):
    return stripe.checkout.Session.create(
        mode="payment",
        payment_method_types=["card"],
        line_items=[
            {
                "price_data": {
                    "currency": "eur",
                    "product_data": {
                        "name": f"ExLibris - Paiement échange #{exchange_id}",
                    },
                    "unit_amount": amount_cents,
                },
                "quantity": 1,
            }
        ],
        success_url=success_url,
        cancel_url=cancel_url,
        metadata={
            "exchange_id": str(exchange_id),
            "payment_id": str(payment_id),
            "user_id": str(user_id),
        },
    )