#!/bin/bash
# setup-eks-access.sh - AWS EKS 클러스터 접속 설정 스크립트

echo "=== AWS EKS 접속 설정 ==="
echo ""

# 1. AWS CLI 확인
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되어 있지 않습니다."
    echo "설치: brew install awscli (macOS) 또는 https://aws.amazon.com/cli/"
    exit 1
fi
echo "✅ AWS CLI 설치 확인됨"

# 2. kubectl 확인
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl이 설치되어 있지 않습니다."
    echo "설치: brew install kubectl (macOS) 또는 https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo "✅ kubectl 설치 확인됨"

# 3. AWS 자격증명 확인
if [ -z "$AWS_ACCESS_KEY_ID" ] && [ ! -f ~/.aws/credentials ]; then
    echo ""
    echo "⚠️  AWS 자격증명이 설정되어 있지 않습니다."
    echo "다음 정보가 필요합니다:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Region: ap-northeast-2 (서울)"
    echo ""
    read -p "지금 설정하시겠습니까? (y/n): " answer
    if [ "$answer" = "y" ]; then
        aws configure
    else
        echo "설정을 건너뜁니다. 나중에 'aws configure' 명령어로 설정하세요."
        exit 1
    fi
else
    echo "✅ AWS 자격증명 확인됨"
fi

# 4. AWS 자격증명 테스트
echo ""
echo "AWS 자격증명 테스트 중..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS 자격증명 유효"
    aws sts get-caller-identity
else
    echo "❌ AWS 자격증명이 유효하지 않습니다."
    echo "다시 설정하세요: aws configure"
    exit 1
fi

# 5. 클러스터 접속 설정
echo ""
echo "=== EKS 클러스터 접속 설정 ==="
CLUSTER_NAME="streaming-cluster"
REGION="ap-northeast-2"

echo "클러스터: $CLUSTER_NAME"
echo "리전: $REGION"
echo ""

# 클러스터 존재 확인
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
    echo "✅ 클러스터 확인됨"
else
    echo "❌ 클러스터를 찾을 수 없습니다."
    echo "클러스터 목록 확인 중..."
    aws eks list-clusters --region $REGION
    exit 1
fi

# kubeconfig 업데이트
echo ""
echo "kubeconfig 설정 중..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# 6. 연결 확인
echo ""
echo "=== 연결 확인 ==="
echo "현재 컨텍스트:"
kubectl config current-context

echo ""
echo "클러스터 정보:"
kubectl cluster-info

echo ""
echo "노드 확인:"
kubectl get nodes

echo ""
echo "✅ 설정 완료!"
echo ""
echo "다음 명령어로 테스트하세요:"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl get pods -n was"
echo "  kubectl get pods -n kafka"
echo "  kubectl get pods -n storage"
echo "  kubectl get pods -n monitoring"
