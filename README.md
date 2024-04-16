# Create a database Trigger in DHIS2

```bash
chmod +x ./bin/setup
./bin/setup
```

-  Start a test dhis2 instance 
```bash
   cd dhis2_test_instance
   docker-compose up -d
```

- Run data migration to create the trigger

```
rake db:migrate
```

- To delete the trigger

```
rake db:rollback
```

- Run tests
```bash
rspec
```

