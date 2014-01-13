
all: build-site deploy

build-site:
	blogofile build
	rm -f _site/README
	mv _site/README.site _site/README

deploy:
	rsync -rvvC --delete _site/ _deploy/
	cd _deploy && git add . && git add -u && git status -s

push:
	cd _deploy && EDITOR=emacs git commit
	cd _deploy && git push 


