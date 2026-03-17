git stash
git pull origin main --rebase
git stash pop
git add .
git commit -m "Průběžné uložení"
git push origin main