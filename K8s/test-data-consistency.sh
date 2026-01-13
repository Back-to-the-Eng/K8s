#!/bin/bash

echo "=== 데이터 일관성 테스트 ==="
echo ""

# 1. WAS에서 생성된 메시지 수 확인
echo "1. WAS 로그 확인..."
WAS_PODS=($(kubectl get pods -n was -o jsonpath='{.items[*].metadata.name}'))
TOTAL_WAS_LOGS=0
for pod in "${WAS_PODS[@]}"; do
    LOG_COUNT=$(kubectl logs -n was $pod 2>/dev/null | grep -c "user-activity" || echo "0")
    echo "  Pod $pod: $LOG_COUNT 개 로그"
    TOTAL_WAS_LOGS=$((TOTAL_WAS_LOGS + LOG_COUNT))
done
echo "  총 WAS 로그: $TOTAL_WAS_LOGS"
echo ""

# 2. Kafka 토픽 메시지 수 확인
echo "2. Kafka 토픽 메시지 수 확인..."
KAFKA_POD=$(kubectl get pods -n kafka -l strimzi.io/cluster=streaming-cluster -o jsonpath='{.items[0].metadata.name}')
if [ -n "$KAFKA_POD" ]; then
    KAFKA_OFFSETS=$(kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic user-activity-logs --time -1" 2>/dev/null)
    KAFKA_TOTAL=0
    for offset in $(echo "$KAFKA_OFFSETS" | awk -F: '{print $3}'); do
        KAFKA_TOTAL=$((KAFKA_TOTAL + offset))
    done
    echo "  Kafka 총 메시지 수: $KAFKA_TOTAL"
else
    echo "  ❌ Kafka Pod를 찾을 수 없습니다"
fi
echo ""

# 3. MinIO Silver 버킷 파일 확인
echo "3. MinIO Silver 버킷 파일 확인..."
MINIO_POD=$(kubectl get pods -n storage -l app=minio -o jsonpath='{.items[0].metadata.name}')
if [ -n "$MINIO_POD" ]; then
    MINIO_FILES=$(kubectl exec $MINIO_POD -n storage -- sh -c "mc alias set myminio http://localhost:9000 admin password1234 && mc find myminio/silver --name '*.parquet' 2>/dev/null | wc -l" 2>/dev/null)
    echo "  MinIO Silver 파일 수: $MINIO_FILES"
else
    echo "  ❌ MinIO Pod를 찾을 수 없습니다"
fi
echo ""

# 4. ClickHouse 데이터 확인
echo "4. ClickHouse 데이터 확인..."
CLICKHOUSE_POD=$(kubectl get pods -n storage -l app=clickhouse -o jsonpath='{.items[0].metadata.name}')
if [ -n "$CLICKHOUSE_POD" ]; then
    CLICKHOUSE_DATA=$(kubectl exec $CLICKHOUSE_POD -n storage -- clickhouse-client --password=backtoeng --query "SELECT table, count() as records FROM system.parts WHERE database = 'logs' AND active = 1 GROUP BY table" 2>/dev/null)
    echo "  ClickHouse 데이터:"
    echo "$CLICKHOUSE_DATA" | while read line; do
        echo "    $line"
    done
else
    echo "  ❌ ClickHouse Pod를 찾을 수 없습니다"
fi
echo ""

# 5. 일관성 검증
echo "5. 일관성 검증..."
echo "  ✅ 모든 단계에서 데이터가 일관되게 처리되었는지 확인하세요"
echo ""

echo "테스트 완료!"
