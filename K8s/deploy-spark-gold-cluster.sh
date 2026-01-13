#!/bin/bash

echo "=== Spark Gold Cluster Mode 배포 스크립트 ==="
echo ""

# 1단계: 기존 Pod 삭제 (Local Mode)
echo "1단계: 기존 spark-gold Pod 삭제..."
kubectl delete pod spark-gold 2>/dev/null || echo "  → spark-gold Pod가 없거나 이미 삭제됨"
echo ""

# 2단계: PVC 생성 확인
echo "2단계: PVC 생성 확인..."
if kubectl get pvc spark-gold-checkpoint-pvc -n default >/dev/null 2>&1; then
    echo "  → PVC가 이미 존재함"
else
    echo "  → PVC 생성 중..."
    kubectl apply -f spark-gold-checkpoint-pvc.yaml
    echo "  → PVC 생성 완료"
fi
echo ""

# 3단계: SparkApplication 배포
echo "3단계: SparkApplication 배포 (Cluster Mode)..."
kubectl apply -f spark-gold-application.yaml
echo "  → SparkApplication 배포 완료"
echo ""

# 4단계: 상태 확인
echo "4단계: 상태 확인..."
echo ""
echo "SparkApplication 상태:"
kubectl get sparkapplication spark-gold-cluster
echo ""
echo "생성된 Pod들:"
kubectl get pods | grep spark-gold-cluster
echo ""
echo "Driver 로그 확인:"
echo "  kubectl logs spark-gold-cluster-driver"
echo ""
echo "Executor 로그 확인:"
echo "  kubectl logs spark-gold-cluster-exec-1"
echo ""
echo "=== 배포 완료 ==="
