setup:
	rm -rf ./vve
	python3.9 -m venv vve
	. ./vve/bin/activate
	./vve/bin/python -m pip install --upgrade pip
	./vve/bin/python -m pip cache purge
	./vve/bin/python -m pip install uv

develop:
	make setup
	./vve/bin/python -m uv pip install -r requirements.txt