
```sql
CREATE OR REPLACE FUNCTION random_bool()
RETURNS boolean AS $$
BEGIN
  RETURN random() < 0.5;
END;
$$ LANGUAGE plpgsql;

select random_bool();
```


https://docs.flutter.dev/platform-integration/linux/building


https://medium.com/@fluttergems/packaging-and-distributing-flutter-desktop-apps-the-missing-guide-part-3-linux-24ef8d30a5b4

