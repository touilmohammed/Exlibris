# ExLibris

ExLibris est une application de gestion de collection de livres. Lorsque vous achetez un livre, vous pouvez l’ajouter à votre collection ExLibris. Vous avez ainsi une trace de votre collection dans votre poche, ce qui évite les achats en doublons. 

Vous pouvez ajouter vos amis, afin de partager vos collections et voir quel genre de livre ils apprécient. Vous pouvez aussi ajouter des livres à votre liste de souhaits, pour savoir quoi acheter une fois dans la librairie. Vos amis ont également accès à cette liste de souhaits et peuvent alors faire des propositions d’échange de livre, en proposant un livre de leur collection.

Les échanges ne sont pas gérés dans l’application (pour l’instant…), ils servent juste à communiquer que vous êtes disposé à vous séparer d’un livre de votre collection en échange d’un autre.

Vous avez aimé un achat récent ? Vous pouvez laisser un avis sur le livre, avec une note allant de 0 à 5 étoiles. Vous avez tellement aimé ce livre que vous voulez le conseiller à vos amis ? Avec Ex Libris, vous pouvez !


## Info 

### Lancer l'application
1. dans le .env.local ajouter: 
API_BASE_URL=http://87.106.141.247/exlibris-api
2. flutter pub get
3. flutter run

### Lancer les tests

```bash
flutter test
```

## Pour aller sur php my admin sur le back

http://87.106.141.247/phpmyadmin

user: exlibris
mdp: exlibris2b