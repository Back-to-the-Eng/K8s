#!/bin/bash

echo "=== 전체 연결 상태 확인 ==="
echo ""
echo "Pod 상태:"
kubectl get pods --all-namespaces | grep -E "kafka|was|spark|clickhouse|minio|prometheus|grafana" | grep -v "spark-operator" | awk '{printf "%-25s %-15s %-10s\n", $2, $1, $4}'
echo ""
echo "서비스 상태:"
kubectl get svc --all-namespaces | grep -E "kafka|was|clickhouse|minio|grafana" | awk '{printf "%-25s %-15s %-10s\n", $2, $1, $5}'
echo ""
echo "요약:"
echo "Kafka: $(kubectl get pods -n kafka -l strimzi.io/cluster=streaming-cluster --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')개 브로커"
echo "WAS: $(kubectl get pods -n was --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')개 Pod"
echo "Spark Streaming: $(kubectl get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | grep spark-streaming | wc -l | tr -d ' ')개 Pod"
echo "Spark Gold: $(kubectl get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | grep spark-gold | wc -l | tr -d ' ')개 Pod"
echo "MinIO: $(kubectl get pods -n storage -l app=minio --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')개 Pod"
echo "ClickHouse: $(kubectl get pods -n storage -l app=clickhouse --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')개 Pod"
echo "Grafana: $(kubectl get pods -n monitoring -l app=grafana --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')개 Pod"
