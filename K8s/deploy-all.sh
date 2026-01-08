#!/bin/bash

set -e

echo "=========================================="
echo "EKS 클러스터 전체 배포 스크립트"
echo "=========================================="

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 클러스터 및 노드 확인
echo -e "${YELLOW}[1/12] 클러스터 및 노드 확인${NC}"
kubectl get nodes
echo ""

# 2. 네임스페이스 생성
echo -e "${YELLOW}[2/12] 네임스페이스 생성${NC}"
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace was --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace spark-operator --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace storage --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}네임스페이스 생성 완료${NC}"
echo ""

# 3. Strimzi Kafka Operator 설치
echo -e "${YELLOW}[3/12] Strimzi Kafka Operator 설치${NC}"
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
echo "Strimzi Operator 설치 중... (약 1-2분 소요)"
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s || true
echo -e "${GREEN}Strimzi Operator 설치 완료${NC}"
echo ""

# 4. Kafka Cluster 배포
echo -e "${YELLOW}[4/12] Kafka Cluster 배포${NC}"
kubectl apply -f kafka-strimzi.yaml
kubectl apply -f kafka-nodepool.yaml
echo "Kafka 클러스터 생성 중... (약 3-5분 소요)"
kubectl wait --for=condition=ready kafka streaming-cluster -n kafka --timeout=600s || true
echo -e "${GREEN}Kafka Cluster 배포 완료${NC}"
echo ""

# 5. Kafka Topics 생성
echo -e "${YELLOW}[5/12] Kafka Topics 생성${NC}"
kubectl apply -f topic.yaml
kubectl apply -f topic-user-activity-logs.yaml
echo -e "${GREEN}Kafka Topics 생성 완료${NC}"
echo ""

# 6. Spark Operator 설치
echo -e "${YELLOW}[6/12] Spark Operator 설치${NC}"
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator 2>/dev/null || true
helm repo update
helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --set webhook.enable=true \
  --wait --timeout=300s || true
echo -e "${GREEN}Spark Operator 설치 완료${NC}"
echo ""

# 7. Spark Resources 배포
echo -e "${YELLOW}[7/12] Spark Resources 배포${NC}"
kubectl apply -f spark-rbac.yaml || kubectl apply -f spark-serviceaccount.yaml
kubectl apply -f spark-code-configmap.yaml
echo -e "${GREEN}Spark Resources 배포 완료${NC}"
echo ""

# 8. WAS 배포
echo -e "${YELLOW}[8/12] WAS 배포${NC}"
kubectl apply -f was-deployment.yaml
kubectl apply -f was-service-external.yaml
kubectl wait --for=condition=ready pod -l app=was -n was --timeout=300s || true
echo -e "${GREEN}WAS 배포 완료${NC}"
echo ""

# 9. MinIO 배포
echo -e "${YELLOW}[9/12] MinIO 배포${NC}"
kubectl apply -f minio-deployment.yaml
kubectl wait --for=condition=ready pod -l app=minio -n storage --timeout=300s || true
echo "MinIO 버킷 생성 중..."
sleep 10
kubectl exec -it $(kubectl get pods -n storage -l app=minio -o jsonpath='{.items[0].metadata.name}') -n storage -- \
  sh -c "mc alias set myminio http://localhost:9000 admin password1234 && mc mb myminio/mybucket --ignore-existing" || true
echo -e "${GREEN}MinIO 배포 완료${NC}"
echo ""

# 10. 모니터링 스택 배포
echo -e "${YELLOW}[10/12] 모니터링 스택 배포${NC}"
kubectl apply -f prometheus-configmap.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f kafka-exporter-deployment.yaml
kubectl apply -f grafana-deployment.yaml
echo -e "${GREEN}모니터링 스택 배포 완료${NC}"
echo ""

# 11. Kafka Connect 배포
echo -e "${YELLOW}[11/12] Kafka Connect 배포${NC}"
kubectl apply -f kafka-connect.yaml
echo -e "${GREEN}Kafka Connect 배포 완료${NC}"
echo ""

# 12. Spark Application 배포
echo -e "${YELLOW}[12/12] Spark Application 배포${NC}"
kubectl apply -f spark-direct.yaml
echo -e "${GREEN}Spark Application 배포 완료${NC}"
echo ""

# 배포 상태 확인
echo "=========================================="
echo -e "${GREEN}전체 배포 완료!${NC}"
echo "=========================================="
echo ""
echo "배포 상태 확인:"
kubectl get pods --all-namespaces
echo ""
echo "서비스 엔드포인트:"
echo "- WAS: NodePort 30080"
echo "- Grafana: NodePort 30300"
echo "- MinIO API: NodePort 30900"
echo "- MinIO Console: NodePort 30901"
echo "- ClickHouse HTTP: NodePort 30812"
echo "- ClickHouse Native: NodePort 30909"
echo ""
echo "참고: 이미지 다운로드로 인해 Pod 시작에 시간이 걸릴 수 있습니다."
echo "      Spark 이미지(1.1GB), Grafana 이미지(210MB), ClickHouse 이미지 등이 첫 다운로드 시 시간이 소요됩니다."
echo "- ClickHouse HTTP: NodePort 30812"
echo "- ClickHouse Native: NodePort 30900"
echo ""
echo "참고: 이미지 다운로드로 인해 Pod 시작에 시간이 걸릴 수 있습니다."
echo "      Spark 이미지(1.1GB), Grafana 이미지(210MB) 등이 첫 다운로드 시 시간이 소요됩니다."