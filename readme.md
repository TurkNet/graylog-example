# GrayLog Examples

Run Dockers

```bash
docker-compose up -d
```

Sample logstash log

```bash
curl -X POST "http://localhost:5601" -H "Content-Type: application/json" -d '{
  "message": "2024-07-30T11:14:43.511Z [main]>worker0 INFO com.example.MainClass - This is a test log message",
  "timestamp": "2024-07-30T11:14:43.511Z",
  "level": "INFO",
  "application": "test_app",
  "host": "localhost"
}'
```
