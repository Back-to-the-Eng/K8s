#!/bin/bash

echo "=========================================="
echo "Spark Gold 상태 확인"
echo "=========================================="

echo -e "\n[1] Spark Gold Pod 상태"
kubectl get pods -n default | grep spark-gold

echo -e "\n[2] Spark Gold 최근 로그 (배치 처리 관련)"
kubectl logs spark-gold -n default --tail=50 2>&1 | grep -E "batch|Wrote to|Error|error|SUCCESS" | tail -10 || echo "로그 없음"

echo -e "\n[3] ClickHouse 테이블별 데이터 개수"
CLICKHOUSE_POD=$(kubectl get pods -n storage -l app=clickhouse --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$CLICKHOUSE_POD" ]; then
    kubectl exec $CLICKHOUSE_POD -n storage -- clickhouse-client --query "
        SELECT 
            'metrics_server_health_minutely' as table_name, 
            count() as record_count,
            max(minute) as latest_time
        FROM logs.metrics_server_health_minutely
        UNION ALL
        SELECT 'metrics_operational_hourly', count(), max(hour) FROM logs.metrics_operational_hourly
        UNION ALL
        SELECT 'metrics_business_daily', count(), max(date) FROM logs.metrics_business_daily
        UNION ALL
        SELECT 'metrics_funnel_hourly', count(), max(hour_bucket) FROM logs.metrics_funnel_hourly
        UNION ALL
        SELECT 'metrics_data_quality_hourly', count(), max(hour) FROM logs.metrics_data_quality_hourly
    " 2>/dev/null || echo "ClickHouse 쿼리 실패"
else
    echo "ClickHouse Pod를 찾을 수 없습니다"
fi

echo -e "\n[4] 최근 적재된 데이터 샘플 (서버 건강도)"
if [ -n "$CLICKHOUSE_POD" ]; then
    kubectl exec $CLICKHOUSE_POD -n storage -- clickhouse-client --query "
        SELECT 
            minute, 
            total_requests, 
            error_requests, 
            round(error_rate, 4) as error_rate,
            unique_users
        FROM logs.metrics_server_health_minutely 
        ORDER BY minute DESC 
        LIMIT 5
    " 2>/dev/null || echo "데이터 없음"
fi

echo -e "\n[5] Spark Gold 에러 확인"
kubectl logs spark-gold -n default --tail=100 2>&1 | grep -i -E "error|exception|failed" | tail -5 || echo "에러 없음"

echo -e "\n=========================================="
echo "확인 완료"
echo "=========================================="

