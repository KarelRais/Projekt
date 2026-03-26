git stash -u
git pull origin main --rebase
git stash pop
git add --all
git commit -m "Prubezne ulozeni"
rem Hacky a carky se na GitHubu spravne nezobrazuji.
git push origin main