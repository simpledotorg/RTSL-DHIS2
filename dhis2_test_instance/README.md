# dhis2-setup

> To start the dhis2 instance
```
cd dhis2_test_instance
docker-compose up -d 
```

### To seed data 

By default, We are using a db dump from staging instance.
If you are using a different db dump, place it in `local/` folder and name the file `db-dump.sql`. 

#### To restore the data from a dump

```
docker exec -i dhis2-db sh -c "psql -U dhis template1 -c 'drop database dhis with (force);'  && \
psql -U dhis template1 -c 'create database dhis with owner dhis;' && \
psql -U dhis -d dhis < /var/lib/postgresql/db-dump.sql"
```
