from core.database import get_db_connection


DEMANDEUR_ID = 66
DESTINATAIRE_ID = 74
DEMANDEUR_EMAIL = "camille.dubois@test.com"
DEMANDEUR_PASSWORD = "pass"
DESTINATAIRE_EMAIL = "camille.garcia@test.com"
DESTINATAIRE_PASSWORD = "pass"


def login_and_get_headers(client, email: str, password: str) -> dict:
    response = client.post(
        "/auth/login",
        json={
            "email": email,
            "mot_de_passe": password,
        },
    )
    assert response.status_code == 200, response.text
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def get_available_exchange_books():
    """
    Récupère dynamiquement un livre chez le demandeur et un livre chez le destinataire.
    """
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT livre_isbn
            FROM Collection
            WHERE utilisateur_id = %s
            ORDER BY date_ajout DESC
            LIMIT 1
            """,
            (DEMANDEUR_ID,),
        )
        demandeur_row = cur.fetchone()

        cur.execute(
            """
            SELECT livre_isbn
            FROM Collection
            WHERE utilisateur_id = %s
            ORDER BY date_ajout DESC
            LIMIT 1
            """,
            (DESTINATAIRE_ID,),
        )
        destinataire_row = cur.fetchone()

        assert demandeur_row is not None, "Aucun livre disponible chez le demandeur"
        assert destinataire_row is not None, "Aucun livre disponible chez le destinataire"

        return demandeur_row[0], destinataire_row[0]

    finally:
        conn.close()


def test_exchange_full_flow(client):
    demandeur_headers = login_and_get_headers(client, DEMANDEUR_EMAIL, DEMANDEUR_PASSWORD)
    destinataire_headers = login_and_get_headers(client, DESTINATAIRE_EMAIL, DESTINATAIRE_PASSWORD)

    livre_demandeur_isbn, livre_destinataire_isbn = get_available_exchange_books()

    # 1. Création échange
    create_resp = client.post(
        "/exchanges",
        headers=demandeur_headers,
        json={
            "destinataire_id": DESTINATAIRE_ID,
            "livre_demandeur_isbn": livre_demandeur_isbn,
            "livre_destinataire_isbn": livre_destinataire_isbn,
        },
    )
    assert create_resp.status_code == 200, create_resp.text
    exchange = create_resp.json()
    exchange_id = exchange["id_echange"]
    assert exchange["statut"] == "demande_envoyee"

    # 2. Acceptation
    accept_resp = client.post(
        f"/exchanges/{exchange_id}/accept",
        headers=destinataire_headers,
    )
    assert accept_resp.status_code == 200, accept_resp.text
    assert accept_resp.json()["statut"] == "demande_acceptee"

    # 3. Création paiement
    payment_resp = client.post(
        f"/exchanges/{exchange_id}/payment",
        headers=demandeur_headers,
        json={"montant": 5.0},
    )
    assert payment_resp.status_code == 200, payment_resp.text
    payment = payment_resp.json()
    payment_id = payment["id_paiement"]
    assert payment["statut"] == "en_attente"

    # 4. Paiement sandbox
    sandbox_resp = client.post(
        f"/payments/{payment_id}/sandbox-pay",
        headers=demandeur_headers,
    )
    assert sandbox_resp.status_code == 200, sandbox_resp.text
    assert sandbox_resp.json()["statut"] == "paye"

    # 5. Confirmation expédition
    ship_resp = client.post(
        f"/exchanges/{exchange_id}/confirm-shipment",
        headers=demandeur_headers,
    )
    assert ship_resp.status_code == 200, ship_resp.text
    assert ship_resp.json()["statut"] == "expedition_confirmee"

    # 6. Confirmation réception
    receive_resp = client.post(
        f"/exchanges/{exchange_id}/confirm-reception",
        headers=destinataire_headers,
    )
    assert receive_resp.status_code == 200, receive_resp.text
    assert receive_resp.json()["statut"] == "termine"

    # 7. Vérification paiement libéré
    payment_status_resp = client.get(
        f"/exchanges/{exchange_id}/payment",
        headers=demandeur_headers,
    )
    assert payment_status_resp.status_code == 200, payment_status_resp.text
    assert payment_status_resp.json()["statut"] == "libere"

    # 8. Vérification collections en base
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (DESTINATAIRE_ID, livre_demandeur_isbn),
        )
        assert cur.fetchone() is not None

        cur.execute(
            """
            SELECT 1
            FROM Collection
            WHERE utilisateur_id = %s AND livre_isbn = %s
            """,
            (DEMANDEUR_ID, livre_destinataire_isbn),
        )
        assert cur.fetchone() is not None
    finally:
        conn.close()