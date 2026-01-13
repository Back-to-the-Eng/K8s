#!/bin/bash

echo "=== Kafka 파티션 분산 처리 확인 ==="
echo ""

KAFKA_POD=$(kubectl get pods -n kafka -l strimzi.io/cluster=streaming-cluster -o jsonpath='{.items[0].metadata.name}')
TOPIC="user-activity-logs"

if [ -z "$KAFKA_POD" ]; then
    echo "❌ Kafka Pod를 찾을 수 없습니다"
    exit 1
fi

echo "Kafka Pod: $KAFKA_POD"
echo "Topic: $TOPIC"
echo ""

# 파티션별 오프셋 확인
echo "=== 파티션별 메시지 수 (오프셋) ==="
kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic $TOPIC --time -1" 2>/dev/null

echo ""
echo "=== 파티션별 리더 브로커 ==="
kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic $TOPIC" 2>/dev/null | grep "Partition:"

echo ""
echo "=== Consumer Group별 파티션 할당 ==="
# Consumer Group이 있다면 파티션 할당 확인
kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list" 2>/dev/null | while read group; do
    if [ -n "$group" ]; then
        echo "Consumer Group: $group"
        kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group $group" 2>/dev/null | grep -E "PARTITION|LAG"
        echo ""
    fi
done

echo ""
echo "테스트 완료!"
