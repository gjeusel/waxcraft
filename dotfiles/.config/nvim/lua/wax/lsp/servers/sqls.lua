return {
  settings = {
    sqls = {
      connections = {
        {
          alias = "peregreen",
          driver = "postgresql",
          dataSourceName = "host=127.0.0.1 port=15432 user=postgres password=postgres dbname=peregreen sslmode=disable",
        },
      },
    },
  },
}
