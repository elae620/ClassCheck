# Modèle de reconnaissance faciale

`mobilefacenet.tflite` : MobileFaceNet (float32), entrée `[1, 112, 112, 3]` (pixels dans
[-1, 1]), sortie `[1, 192]` (nom du tenseur : `embeddings`). Environ 5 Mo.

Pipeline (voir `lib/features/face/data/face_embedding_service.dart`) :

1. ML Kit détecte le visage et les yeux ; contrôle de pose (de face, assez grand, yeux ouverts).
2. Alignement sur les yeux → visage 112×112 cadré comme les données d'entraînement.
3. Contrôle de netteté et d'éclairage.
4. Embedding de l'image + embedding de son miroir, moyenne puis normalisation L2.

Si le fichier est absent ou illisible, l'application utilise une implémentation **factice**
(`FakeFaceEmbeddingService`, badge « Mode démo ») qui **ne distingue pas fiablement deux
personnes** : ne l'utilisez pas en démonstration finale.

Provenance : modèle MobileFaceNet pré-entraîné publié dans le dépôt GitHub public
`MCarlomagno/FaceRecognitionAuth` (`assets/mobilefacenet.tflite`, 5 233 552 octets).
