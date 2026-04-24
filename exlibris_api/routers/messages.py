from fastapi import APIRouter, Depends, HTTPException
from typing import List
from pydantic import BaseModel
from datetime import datetime
from core.database import get_db_connection
from dependencies.auth import get_current_user_id

router = APIRouter(prefix="/messages", tags=["Messages"])

class MessageOut(BaseModel):
    id_message: int
    expediteur_id: int
    destinataire_id: int
    contenu: str
    date_envoi: datetime

class MessageIn(BaseModel):
    contenu: str

@router.get("/{friend_id}", response_model=List[MessageOut])
def get_messages(friend_id: int, current_user_id: int = Depends(get_current_user_id)):
    """Récupère l'historique des messages entre l'utilisateur courant et un ami."""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        # Marquer comme lus les messages reçus de cet ami
        sql_update = """
            UPDATE Message
            SET lu = TRUE
            WHERE expediteur_id = %s AND destinataire_id = %s AND lu = FALSE
        """
        cur.execute(sql_update, (friend_id, current_user_id))
        conn.commit()

        sql = """
            SELECT id_message, expediteur_id, destinataire_id, contenu, date_envoi
            FROM Message
            WHERE (expediteur_id = %s AND destinataire_id = %s)
               OR (expediteur_id = %s AND destinataire_id = %s)
            ORDER BY date_envoi ASC
        """
        cur.execute(sql, (current_user_id, friend_id, friend_id, current_user_id))
        rows = cur.fetchall()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
    conn.close()

    return [
        MessageOut(
            id_message=row[0],
            expediteur_id=row[1],
            destinataire_id=row[2],
            contenu=row[3],
            date_envoi=row[4]
        )
        for row in rows
    ]

@router.post("/{friend_id}", response_model=MessageOut)
def send_message(friend_id: int, message: MessageIn, current_user_id: int = Depends(get_current_user_id)):
    """Envoie un message à un ami."""
    
    if len(message.contenu.strip()) == 0:
        raise HTTPException(status_code=400, detail="Le message ne peut pas être vide")
        
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Optionnel : vérifier si l'amitié existe et est 'accepte'
        sql_check = """
            SELECT 1 FROM Amitie 
            WHERE ((utilisateur_1_id = %s AND utilisateur_2_id = %s) 
               OR (utilisateur_1_id = %s AND utilisateur_2_id = %s))
              AND statut = 'accepte'
        """
        cur.execute(sql_check, (current_user_id, friend_id, friend_id, current_user_id))
        if not cur.fetchone():
             conn.close()
             raise HTTPException(status_code=403, detail="Vous n'êtes pas amis avec cet utilisateur")

        sql_insert = """
            INSERT INTO Message (expediteur_id, destinataire_id, contenu)
            VALUES (%s, %s, %s)
        """
        cur.execute(sql_insert, (current_user_id, friend_id, message.contenu.strip()))
        conn.commit()
        
        # Récupérer le message inséré (avec id et date)
        new_id = cur.lastrowid
        cur.execute("SELECT id_message, expediteur_id, destinataire_id, contenu, date_envoi FROM Message WHERE id_message = %s", (new_id,))
        row = cur.fetchone()
        
    except HTTPException:
        raise
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")
        
    conn.close()

    return MessageOut(
        id_message=row[0],
        expediteur_id=row[1],
        destinataire_id=row[2],
        contenu=row[3],
        date_envoi=row[4]
    )
