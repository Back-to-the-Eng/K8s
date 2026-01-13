#!/bin/bash

echo "=== WAS 동시성 쓰기 테스트 ==="
echo ""

# WAS Pod 목록
WAS_PODS=($(kubectl get pods -n was -o jsonpath='{.items[*].metadata.name}'))
NODE_PORT=$(kubectl get svc was-service-external -n was -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo "WAS Pod 개수: ${#WAS_PODS[@]}"
echo "테스트 시작 시간: $(date)"
echo ""

# 각 Pod에서 동시에 요청 보내기
echo "각 Pod에서 동시에 50개 요청 전송..."
for i in {1..50}; do
    for pod in "${WAS_PODS[@]}"; do
        curl -s "http://$NODE_IP:$NODE_PORT/main" > /dev/null 2>&1 &
    done
done

# 모든 요청 완료 대기
wait

echo ""
echo "요청 완료 시간: $(date)"
echo ""

# Kafka 토픽 메시지 수 확인
echo "=== Kafka 토픽 메시지 수 확인 ==="
KAFKA_POD=$(kubectl get pods -n kafka -l strimzi.io/cluster=streaming-cluster -o jsonpath='{.items[0].metadata.name}')
if [ -n "$KAFKA_POD" ]; then
    kubectl exec $KAFKA_POD -n kafka -- sh -c "/opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic user-activity-logs --time -1" 2>/dev/null | awk -F: '{sum+=$3} END {print "총 메시지 수:", sum}'
fi

echo ""
echo "테스트 완료!"
