# Kubernetes Deployment for Streaming Data Pipeline

이 프로젝트는 Amazon EKS(Elastic Kubernetes Service) 클러스터에 실시간 데이터 스트리밍 파이프라인을 배포하기 위한 Kubernetes 매니페스트 파일들을 포함합니다.

## Architecture Overview

시스템은 다음과 같은 컴포넌트로 구성됩니다:

```
Web Application Server (WAS)
    |
    v
Kafka Cluster (Strimzi)
    |
    v
Spark Streaming Application
```

### Component Flow

1. **Web Application Server**: 사용자 활동 로그를 생성하고 Kafka로 전송
2. **Kafka Cluster**: 메시지 브로커로 실시간 데이터 스트리밍 허브 역할
3. **Spark Application**: Kafka에서 데이터를 소비하여 실시간 처리

## Prerequisites

- Amazon EKS 클러스터 (eksctl로 생성)
- kubectl 설치 및 클러스터 접근 권한
- Strimzi Kafka Operator 설치
- Spark Operator 설치

## Namespace Structure

시스템은 다음 네임스페이스로 구성됩니다:

- `kafka`: Kafka 클러스터 및 관련 리소스
- `was`: Web Application Server
- `logging-system`: Log Generator
- `default`: Spark Application 및 관련 리소스
- `spark-operator`: Spark Operator

## Deployment Components

### 1. Kafka Infrastructure

#### Kafka Cluster (Strimzi)
- **File**: `kafka-strimzi.yaml`, `kafka-nodepool.yaml`
- **Namespace**: `kafka`
- **Cluster Name**: `streaming-cluster`
- **Brokers**: 3개
- **Version**: Kafka 3.7.0
- **Storage**: Persistent Volume (10Gi per broker)

#### Kafka Topic
- **File**: `topic.yaml`
- **Topic Name**: `streaming-topic`
- **Partitions**: 3
- **Replication Factor**: 3
- **Retention**: 600000ms (10 minutes)

#### Kafka Service
- **Bootstrap Service**: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Type**: ClusterIP
- **Port**: 9092

### 2. Web Application Server (WAS)

#### Deployment
- **File**: `was-deployment.yaml`
- **Namespace**: `was`
- **Replicas**: 2
- **Image**: `ji0513ji/log-generator:1.1.1`
- **Port**: 8080
- **Resources**:
  - Requests: 512Mi memory, 500m CPU
  - Limits: 1Gi memory, 1000m CPU

#### Health Checks
- **Liveness Probe**: `/main` endpoint, 60초 초기 지연
- **Readiness Probe**: `/main` endpoint, 30초 초기 지연

#### Services
- **Internal Service**: `was-service` (ClusterIP, port 80)
- **External Service**: `was-service-external` (NodePort, port 30080)

#### Environment Variables
- `KAFKA_BOOTSTRAP_SERVERS`: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

### 3. Spark Application

#### SparkApplication Resource
- **File**: `spark-app.yaml`
- **Namespace**: `default`
- **Type**: Python
- **Mode**: cluster
- **Spark Version**: 3.5.1
- **Image**: `doyoomii/spark-k8s:latest`
- **Main Application**: `user_activity_streaming.py`

#### Driver Configuration
- **Cores**: 1
- **Memory**: 1g
- **Service Account**: `spark`

#### Executor Configuration
- **Cores**: 1
- **Memory**: 2g
- **Instances**: 2

#### Spark Configuration
- `spark.kubernetes.container.image.pullPolicy`: Always
- `spark.kubernetes.driver.podTemplateFile`: "" (빈 문자열로 설정하여 Spark Operator 템플릿 마운트 문제 해결)
- `spark.kubernetes.executor.podTemplateFile`: "" (빈 문자열로 설정하여 Spark Operator 템플릿 마운트 문제 해결)

#### Environment Variables
- `KAFKA_BOOTSTRAP_SERVERS`: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

#### Supporting Resources
- **ServiceAccount**: `spark-serviceaccount.yaml`
- **ConfigMap**: `spark-code-configmap.yaml` (Spark 스트리밍 코드 포함)

### 4. Log Generator

#### Deployment
- **File**: `log-generator.yaml`
- **Namespace**: `logging-system`
- **Replicas**: 1
- **Image**: `ji0513ji/log-generator:1.1.1`

#### Environment Variables
- `KAFKA_BOOTSTRAP_SERVERS`: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

## Deployment Instructions

### 1. EKS Cluster Setup

```bash
# eksctl을 사용한 클러스터 생성 (cluster.yaml 참조)
eksctl create cluster -f cluster.yaml
```

### 2. Strimzi Kafka Operator 설치

```bash
kubectl create namespace kafka
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
```

### 3. Kafka Cluster 배포

```bash
kubectl apply -f kafka-strimzi.yaml
kubectl apply -f kafka-nodepool.yaml
kubectl apply -f topic.yaml
```

### 4. Spark Operator 설치

```bash
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
helm install spark-operator spark-operator/spark-operator --namespace spark-operator --create-namespace
```

### 5. Spark Resources 배포

```bash
kubectl apply -f spark-serviceaccount.yaml
kubectl apply -f spark-code-configmap.yaml
```

### 6. WAS 배포

```bash
kubectl create namespace was
kubectl apply -f was-deployment.yaml
kubectl apply -f was-service-external.yaml
```

### 7. Log Generator 배포

```bash
kubectl create namespace logging-system
kubectl apply -f log-generator.yaml
```

### 8. Spark Application 배포

```bash
kubectl apply -f spark-app.yaml
```

## Verification

### 전체 리소스 상태 확인

```bash
kubectl get pods --all-namespaces
```

### Kafka 클러스터 확인

```bash
kubectl get kafka -n kafka
kubectl get kafkatopic -n kafka
kubectl get pods -n kafka
```

### WAS 상태 확인

```bash
kubectl get pods -n was
kubectl get svc -n was
```

### Spark Application 상태 확인

```bash
kubectl get sparkapplication -n default
kubectl get pods -n default | grep spark
```

## Service Endpoints

### Kafka Bootstrap Server
- **Internal**: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Topic**: `streaming-topic`

### WAS Services
- **Internal**: `was-service.was.svc.cluster.local:80`
- **External**: `<NodeIP>:30080`

## Configuration Details

### Kafka Configuration
- **Replication Factor**: 3 (모든 토픽)
- **Min In-Sync Replicas**: 2
- **Listener Type**: Internal (TLS 비활성화)
- **Port**: 9092

### WAS Configuration
- **Health Check Endpoint**: `/main`
- **Resource Limits**: 1Gi memory, 1000m CPU
- **Replica Count**: 2

### Spark Configuration
- **Pod Template File**: 빈 문자열로 설정하여 Spark Operator의 템플릿 마운트 문제 해결
- **Kafka Consumer**: `streaming-topic` 구독
- **Executor Count**: 2

## Troubleshooting

### Spark Application 실패 시

Spark Operator가 Pod 템플릿 파일을 마운트하지 못하는 문제가 발생할 수 있습니다. 이를 해결하기 위해 `spark-app.yaml`의 `sparkConf`에 다음 설정을 추가했습니다:

```yaml
sparkConf:
  spark.kubernetes.driver.podTemplateFile: ""
  spark.kubernetes.executor.podTemplateFile: ""
```

### Kafka 연결 문제

모든 서비스는 다음 주소로 Kafka에 연결해야 합니다:
- `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

잘못된 주소 사용 시 연결이 실패할 수 있습니다.

### 네임스페이스 확인

WAS는 `was` 네임스페이스에 배포되며, Kafka는 `kafka` 네임스페이스에 배포됩니다. 네임스페이스가 올바르게 설정되었는지 확인하세요.

## File Structure

```
K8s/
├── cluster.yaml                 # EKS 클러스터 설정
├── kafka-strimzi.yaml          # Kafka 클러스터 정의
├── kafka-nodepool.yaml         # Kafka Node Pool 설정
├── topic.yaml                  # Kafka Topic 정의
├── was-deployment.yaml          # WAS Deployment 및 Service
├── was-service-external.yaml   # WAS 외부 접근 Service
├── spark-app.yaml              # Spark Application 정의
├── spark-serviceaccount.yaml   # Spark ServiceAccount
├── spark-code-configmap.yaml   # Spark 스트리밍 코드
├── log-generator.yaml          # Log Generator Deployment
└── zookeeper.yaml              # Zookeeper 설정 (선택적)
```

## Network Architecture

### Internal Communication
- WAS → Kafka: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- Spark → Kafka: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- Log Generator → Kafka: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

### External Access
- WAS: NodePort 30080을 통해 클러스터 외부에서 접근 가능

## Resource Requirements

### Minimum Requirements
- **Kafka**: 3개 노드 (각 10Gi 스토리지)
- **WAS**: 2개 Pod (각 1Gi memory, 1000m CPU)
- **Spark**: Driver 1개, Executor 2개 (각 2g memory)

### Recommended Node Configuration
- **Instance Type**: m6i.large 이상
- **Node Count**: 최소 3개
- **Storage**: 각 노드당 50Gi 이상

## Security Considerations

- Kafka는 현재 내부 통신만 허용 (TLS 비활성화)
- WAS는 NodePort를 통해 외부 접근 가능 (프로덕션 환경에서는 Ingress 사용 권장)
- Spark ServiceAccount는 최소 권한으로 설정

## Monitoring and Logging

### Pod 로그 확인

```bash
# WAS 로그
kubectl logs -n was -l app=was --tail=100

# Spark Application 로그
kubectl logs -n default spark-kafka-consumer-driver

# Kafka 브로커 로그
kubectl logs -n kafka streaming-cluster-broker-pool-0
```

### Spark Application 상태 모니터링

```bash
kubectl describe sparkapplication spark-kafka-consumer -n default
```

## Maintenance

### 업데이트 절차

1. 매니페스트 파일 수정
2. `kubectl apply -f <file>` 명령으로 변경사항 적용
3. Deployment의 경우 자동으로 롤링 업데이트 수행
4. SparkApplication의 경우 삭제 후 재생성 필요

### 백업 및 복구

- Kafka Topic 데이터는 Persistent Volume에 저장됨
- 중요한 데이터의 경우 정기적인 백업 권장
- ConfigMap 및 Secret은 별도로 백업 필요

## References

- [Strimzi Kafka Operator Documentation](https://strimzi.io/)
- [Spark on Kubernetes Operator](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)

## License

이 프로젝트는 내부 사용을 위한 것입니다.
