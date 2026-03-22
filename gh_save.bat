git stash -u
git pull origin main --rebase
git stash pop
git add --all
git commit -m "Průběžné uložení"
git push origin main