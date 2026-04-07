from typing import Optional
from pydantic import BaseModel


class ExchangeCreate(BaseModel):
    destinataire_id: int
    livre_demandeur_isbn: str
    livre_destinataire_isbn: str


class ExchangeOut(BaseModel):
    id_echange: int
    demandeur_id: int
    destinataire_id: int
    livre_demandeur_isbn: str
    livre_demandeur_titre: Optional[str] = None
    livre_destinataire_isbn: str
    livre_destinataire_titre: Optional[str] = None
    statut: str
    date_creation: Optional[str] = None
    date_derniere_maj: Optional[str] = None


def row_to_exchange(row) -> ExchangeOut:
    return ExchangeOut(
        id_echange=row[0],
        demandeur_id=row[1],
        destinataire_id=row[2],
        livre_demandeur_isbn=row[3],
        livre_demandeur_titre=row[4],
        livre_destinataire_isbn=row[5],
        livre_destinataire_titre=row[6],
        statut=row[7],
        date_creation=str(row[8]) if row[8] else None,
        date_derniere_maj=str(row[9]) if row[9] else None,
    )