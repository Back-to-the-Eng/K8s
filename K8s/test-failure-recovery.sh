#!/bin/bash

echo "=== 장애 복구 테스트 ==="
echo ""

# 현재 WAS Pod 상태
echo "1. 현재 WAS Pod 상태:"
kubectl get pods -n was -o wide
echo ""

# WAS Pod 하나 선택해서 삭제
WAS_PODS=($(kubectl get pods -n was -o jsonpath='{.items[*].metadata.name}'))
if [ ${#WAS_PODS[@]} -eq 0 ]; then
    echo "❌ WAS Pod를 찾을 수 없습니다"
    exit 1
fi

TARGET_POD=${WAS_PODS[0]}
echo "2. Pod 삭제: $TARGET_POD"
kubectl delete pod $TARGET_POD -n was
echo ""

# Pod 재시작 모니터링
echo "3. Pod 재시작 모니터링 (30초)..."
for i in {1..30}; do
    sleep 1
    STATUS=$(kubectl get pods -n was -o jsonpath='{.items[?(@.metadata.name=="'$TARGET_POD'")].status.phase}' 2>/dev/null)
    if [ -z "$STATUS" ]; then
        # Pod가 삭제되고 새 Pod가 생성 중
        NEW_PODS=($(kubectl get pods -n was -o jsonpath='{.items[*].metadata.name}'))
        echo "  새 Pod 생성 중... (${#NEW_PODS[@]}개 Pod)"
    else
        echo "  Pod 상태: $STATUS"
    fi
done
echo ""

# 최종 상태 확인
echo "4. 최종 WAS Pod 상태:"
kubectl get pods -n was -o wide
echo ""

# 서비스 연결 테스트
echo "5. 서비스 연결 테스트..."
NODE_PORT=$(kubectl get svc was-service-external -n was -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

for i in {1..10}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODE_PORT/main" 2>/dev/null)
    if [ "$RESPONSE" = "200" ]; then
        echo "  ✅ 요청 $i: 성공 (HTTP $RESPONSE)"
    else
        echo "  ❌ 요청 $i: 실패 (HTTP $RESPONSE)"
    fi
    sleep 1
done
echo ""

echo "테스트 완료!"
