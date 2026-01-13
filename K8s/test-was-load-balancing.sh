#!/bin/bash

echo "=== WAS 로드 밸런싱 테스트 ==="
echo ""

# WAS Service 엔드포인트 확인
WAS_SERVICE="was-service-external.was.svc.cluster.local"
NODE_PORT=$(kubectl get svc was-service-external -n was -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo "WAS Service: $WAS_SERVICE"
echo "NodePort: $NODE_PORT"
echo "Node IP: $NODE_IP"
echo ""

# 현재 WAS Pod 목록
echo "현재 WAS Pod 목록:"
kubectl get pods -n was -o wide
echo ""

# 각 Pod의 로그에서 요청을 추적할 수 있도록 Pod 이름 확인
WAS_PODS=($(kubectl get pods -n was -o jsonpath='{.items[*].metadata.name}'))
echo "WAS Pod 개수: ${#WAS_PODS[@]}"
echo ""

# 부하 테스트: 여러 요청을 동시에 보내기
echo "부하 테스트 시작 (100개 요청)..."
echo ""

# 각 요청이 어떤 Pod로 가는지 확인하기 위해 로그 모니터링 시작
for pod in "${WAS_PODS[@]}"; do
    echo "Pod $pod 로그 모니터링 시작..."
    kubectl logs -n was $pod --tail=0 -f &
    LOG_PID=$!
    echo $LOG_PID > /tmp/was-log-$pod.pid
done

# 100개 요청을 동시에 보내기
for i in {1..100}; do
    curl -s "http://$NODE_IP:$NODE_PORT/main" > /dev/null 2>&1 &
done

# 모든 요청이 완료될 때까지 대기
wait

echo ""
echo "요청 완료. 로그 확인 중..."
sleep 2

# 로그 모니터링 종료
for pod in "${WAS_PODS[@]}"; do
    if [ -f /tmp/was-log-$pod.pid ]; then
        PID=$(cat /tmp/was-log-$pod.pid)
        kill $PID 2>/dev/null
        rm /tmp/was-log-$pod.pid
    fi
done

# 각 Pod의 최근 로그 확인
echo ""
echo "=== 각 Pod의 최근 요청 로그 ==="
for pod in "${WAS_PODS[@]}"; do
    echo ""
    echo "Pod: $pod"
    kubectl logs -n was $pod --tail=20 | grep -E "GET|POST|Request" | tail -5
done

echo ""
echo "테스트 완료!"
