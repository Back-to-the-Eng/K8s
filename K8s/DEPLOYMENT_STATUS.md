# 배포 상태 및 아키텍처

## 최종 배포 상태

### API-Server docker-compose.yml 기준 전체 비교

| 구성 요소 | docker-compose.yml | K8s 배포 | 상태 | 네임스페이스 |
|---------|-------------------|---------|------|------------|
| Zookeeper | 있음 | Strimzi 관리 | 정상 | kafka |
| Kafka | 있음 | Strimzi Kafka | 정상 | kafka |
| Kafka Connect | 없음 | 배포됨 (추가) | 정상 | kafka |
| MinIO | 있음 | 배포됨 | 정상 | storage |
| Spark Streaming | 있음 | 배포됨 | 정상 | default |
| WAS | 있음 | 배포됨 | 정상 | was |
| Kafka Exporter | 있음 | 배포됨 | 정상 | monitoring |
| Prometheus | 있음 | 배포됨 | 정상 | monitoring |
| Grafana | 있음 | 배포됨 | 정상 | monitoring |

---

## 현재 배포 상태 상세

### 1. Kafka 클러스터
- **네임스페이스**: `kafka`
- **브로커**: 3개 (streaming-cluster-broker-pool-0, 1, 2)
- **Kafka Connect**: 2개 (streaming-connect-cluster-connect-0, 1)
- **Strimzi Operator**: 실행 중
- **토픽**: 
  - `user-activity-logs` (WAS와 Spark가 사용, 3 파티션, 3 리플리케이션)
- **서비스**: 
  - `streaming-cluster-kafka-bootstrap` (ClusterIP)
  - `streaming-cluster-kafka-brokers` (ClusterIP)
  - `streaming-connect-cluster-connect-api` (ClusterIP)

### 2. WAS (Web Application Server)
- **네임스페이스**: `was`
- **Pod 개수**: 2개
- **이미지**: ji0513ji/log-generator:1.1.2
- **서비스**: `was-service-external` (NodePort 30080)
- **Kafka 연결**: `streaming-cluster-kafka-bootstrap.kafka.svc:9092`
- **사용 토픽**: `user-activity-logs`

### 3. Spark Streaming
- **네임스페이스**: `default`
- **Pod**: spark-streaming
- **이미지**: doyoomii/spark-k8s:latest
- **상태**: 정상 실행 중
- **Kafka 연결**: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **MinIO 연결**: `http://minio.storage.svc.cluster.local:9000`
- **S3A 라이브러리**: 추가됨

### 4. Monitoring Stack
- **네임스페이스**: `monitoring`
- **Prometheus**: 정상 실행 중
- **Grafana**: 정상 실행 중 (NodePort 30300)
- **Kafka Exporter**: 정상 실행 중
- **서비스**:
  - `prometheus` (ClusterIP 9090)
  - `grafana` (ClusterIP 3000)
  - `grafana-external` (NodePort 30300)
  - `kafka-exporter` (ClusterIP 9308)

### 5. Storage
- **네임스페이스**: `storage`
- **MinIO**: 정상 실행 중
- **서비스**:
  - `minio` (ClusterIP 9000, 9001)
  - `minio-external` (NodePort 30900, 30901)

---

## 아키텍처 다이어그램

```
WAS (was namespace)
    |
    v
Kafka Cluster (kafka namespace)
    |                          |
    |                          v
    |                    Kafka Connect
    |                          |
    v                          v
Spark Application          Monitoring Stack
(default namespace)       (monitoring namespace)
    |                          |
    v                          v
MinIO (storage namespace)  Prometheus → Grafana
```

---

## 연결 상태

### 1. WAS → Kafka
- **설정**: `SPRING_KAFKA_BOOTSTRAP_SERVERS=streaming-cluster-kafka-bootstrap.kafka.svc:9092`
- **토픽**: `user-activity-logs`
- **상태**: 정상

### 2. Spark → Kafka
- **설정**: `KAFKA_BOOTSTRAP_SERVERS=streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **토픽**: `user-activity-logs`
- **상태**: 정상

### 3. Spark → MinIO
- **설정**: `fs.s3a.endpoint=http://minio.storage.svc.cluster.local:9000`
- **버킷**: mybucket
- **상태**: 정상

### 4. Prometheus → Kafka Exporter
- **포트**: 9308
- **상태**: 정상

### 5. Grafana → Prometheus
- **상태**: 정상

---

## 서비스 엔드포인트

### 외부 접근 가능한 서비스
- **WAS**: NodePort 30080
- **Grafana**: NodePort 30300
- **MinIO API**: NodePort 30900
- **MinIO Console**: NodePort 30901

### 내부 접근 서비스
- **Kafka Bootstrap**: `streaming-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Prometheus**: `prometheus.monitoring.svc.cluster.local:9090`
- **Kafka Connect API**: `streaming-connect-cluster-connect-api.kafka.svc.cluster.local:8083`

---

## 배포 완료 상태

- 모든 구성 요소가 K8s에 배포됨
- docker-compose.yml의 모든 서비스가 K8s로 마이그레이션됨
- 추가 구성 요소 (Kafka Connect)도 배포됨
- 모든 Pod가 정상 실행 중
- 모든 연결이 정상 작동

**배포 완성도: 100%**
