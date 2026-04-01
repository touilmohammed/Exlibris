from typing import Optional
from pydantic import BaseModel


class ExchangePaymentCreate(BaseModel):
    montant: float


class ExchangePaymentOut(BaseModel):
    id_paiement: int
    echange_id: int
    payeur_id: int
    montant: float
    devise: str
    provider: str
    statut: str
    date_creation: Optional[str] = None
    date_paiement: Optional[str] = None
    date_derniere_maj: Optional[str] = None


def row_to_exchange_payment(row) -> ExchangePaymentOut:
    return ExchangePaymentOut(
        id_paiement=row[0],
        echange_id=row[1],
        payeur_id=row[2],
        montant=float(row[3]),
        devise=row[4],
        provider=row[5],
        statut=row[6],
        date_creation=str(row[7]) if row[7] else None,
        date_paiement=str(row[8]) if row[8] else None,
        date_derniere_maj=str(row[9]) if row[9] else None,
    )