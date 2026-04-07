from pydantic import BaseModel, EmailStr


class SignUpBody(BaseModel):
    email: EmailStr
    nom_utilisateur: str
    mot_de_passe: str


class LoginBody(BaseModel):
    email: EmailStr
    mot_de_passe: str


class ConfirmBody(BaseModel):
    email: EmailStr
    code: str


class ResendConfirmationBody(BaseModel):
    email: EmailStr