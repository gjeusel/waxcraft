# Install:

## redis
A RAM db to cache up datas quickly:
pacman -S redis
systemctl start redis

## rabbitmq
(Choose redis or rabbitmq)
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

# Tourbillon launching:
> python -m tourbillon runserver
> celery -A tourbillon.tasks worker --loglevel=info

Every 10 sc push datas from cache to db:
> celery beat -A tourbillon.tasks --max-interval '10'

# Tourbillon Client:
> pip install tourbillon-client

In ipython:
	import tourbillon_client
	trb = tourbillon_client.Client('http://127.0.0.1:5000/', user='gjeusel',
		password='mdp')


# User Experience:

- can't create tables with names like '99999' as :

```
~/src/tourbillon/tourbillon/lib/connection.py in <module>()
      1 with self.cursor(readonly=False) as cr:
----> 2     cr.execute(create_qr % tablename)

ProgrammingError: ERREUR:  erreur de syntaxe sur ou près de « .99999 »
LINE 2:         CREATE TABLE public.99999 (
```
        create_qr = '''
                CREATE TABLE public.%s (
                    version timestamp not null,
                    ts timestamp not null,
                    value float not null
                )'''

```
should be:
```
        create_qr = '''
                CREATE TABLE public."%s" (
                    version timestamp not null,
                    ts timestamp not null,
                    value float not null
                )'''

```

This should implicate a lot more regarding sql requests


- df.index.tz should be set to 'UTC' in order that
`trb_client.write(table='something', data=df, version="2018-02-18")` really get
the timezone info.
