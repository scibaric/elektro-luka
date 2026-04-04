rsync -avz --delete \
  --exclude='.git' \
  --exclude='.idea' \
  --exclude='.gitignore' \
  --exclude='.gitattributes' \
  --exclude='.editorconfig' \
  --exclude='LICENSE.txt' \
  /home/scibaric/work/git/elektro-luka/ \
  elektro-luka:/var/www/elektro-luka
