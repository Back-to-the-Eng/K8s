#!/bin/bash

echo "=========================================="
echo "분산 환경 전체 테스트 스크립트"
echo "=========================================="
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 테스트 선택
echo "테스트할 항목을 선택하세요:"
echo "1. WAS 로드 밸런싱 테스트"
echo "2. Kafka 파티션 분산 확인"
echo "3. 동시성 쓰기 테스트"
echo "4. 데이터 일관성 테스트"
echo "5. 장애 복구 테스트"
echo "6. WAS 스케일링 테스트"
echo "7. 전체 테스트 실행"
echo ""
read -p "선택 (1-7): " choice

case $choice in
    1)
        echo -e "${GREEN}WAS 로드 밸런싱 테스트 시작...${NC}"
        ./test-was-load-balancing.sh
        ;;
    2)
        echo -e "${GREEN}Kafka 파티션 분산 확인 시작...${NC}"
        ./test-kafka-partition-distribution.sh
        ;;
    3)
        echo -e "${GREEN}동시성 쓰기 테스트 시작...${NC}"
        ./test-concurrent-writes.sh
        ;;
    4)
        echo -e "${GREEN}데이터 일관성 테스트 시작...${NC}"
        ./test-data-consistency.sh
        ;;
    5)
        echo -e "${GREEN}장애 복구 테스트 시작...${NC}"
        ./test-failure-recovery.sh
        ;;
    6)
        echo -e "${GREEN}WAS 스케일링 테스트 시작...${NC}"
        echo ""
        echo "현재 WAS Pod 수:"
        kubectl get pods -n was --no-headers | wc -l | tr -d ' '
        echo ""
        read -p "스케일할 Pod 수를 입력하세요 (예: 4, 6): " replicas
        kubectl scale deployment was-deployment --replicas=$replicas -n was
        echo "스케일링 완료. Pod 상태 확인 중..."
        sleep 5
        kubectl get pods -n was -o wide
        ;;
    7)
        echo -e "${GREEN}전체 테스트 실행...${NC}"
        echo ""
        echo "1. WAS 로드 밸런싱 테스트"
        ./test-was-load-balancing.sh
        echo ""
        echo "2. Kafka 파티션 분산 확인"
        ./test-kafka-partition-distribution.sh
        echo ""
        echo "3. 동시성 쓰기 테스트"
        ./test-concurrent-writes.sh
        echo ""
        echo "4. 데이터 일관성 테스트"
        ./test-data-consistency.sh
        echo ""
        echo "5. 장애 복구 테스트"
        ./test-failure-recovery.sh
        echo ""
        echo -e "${GREEN}전체 테스트 완료!${NC}"
        ;;
    *)
        echo -e "${RED}잘못된 선택입니다.${NC}"
        exit 1
        ;;
esac

echo ""
echo "테스트 완료!"
