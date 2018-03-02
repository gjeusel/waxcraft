# Install:

## redis
A RAM db to cache up datas quickly:
pacman -S redis
systemctl start redis

## rabbitmq
pacman -S rabbitmq
systemctl start rabbitmq

## celery:
handle scheduler:
pip install celery

# Tourbillon config:

in $HOME/.tourbillon_settings.py :
	POSTGRES_USER = 'postgres'
	POSTGRES_PASSWORD = 'postgres'
	POSTGRES_DB = 'tourbillon_test'
	POSTGRES_HOST = '192.168.56.1:5432'

and Var Env:
export TOURBILLON_CONFIG=$HOME/.tourbillon_settings.py

> python -m tourbillon setup_first
> python -m tourbillon user create gjeusel -p mdp
> python -m tourbillon group create intraday
> python -m tourbillon group add gjeusel

# Tourbillon Client:
> pip install tourbillon-client

In ipython:
	import tourbillon_client
	trb = tourbillon_client.Client('http://127.0.0.1:5000/', user='gjeusel',
		password='mdp')

