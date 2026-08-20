# 개요
- Bronze (raw 데이터 저장, 모은 단위 중요)
  - log generator => kinesis => firehose(1Mib/60s) => s3 bronze (raw data, GZIP)
- Silver (raw 데이터 -> 정제/전처리등 데이터 조작 -> 저장)
  - Streamming Ingestion => `Streamming Processing + Medalion Architecture`
  - step 1
    - log generator => kinesis(input) => flink(자바,파이썬(pyflink), pom.xml,maven) => kinesis(outut) => firehose => s3 silver
  - step 2
    - log generator => kinesis(input) => lambda => kinesis(outut) => firehose => s3 silver

```
                                    ┌─→ KDF #1 → S3 (Bronze, 원본 그대로)
Log Generator → KDS(단일 스트림) ──┤
                                    └─→ Flink/Lambda(전처리) → KDS(output) → KDF #2 → S3 (Silver, 가공됨)


```

# Flink
- 실시간으로 스트리밍 데이터에서 실행 가능한 분석 정보를 확보
  - 실시간 데이터를 실시간으로 전처리/정제 등 작업 가능 → 지연 거의 없음

- 실시간일 필요 없다면 → 배치 처리 엔진 사용

- Silver 단계로 저장하는 방법
  - [실시간] 처리 엔진 → Flink, Lambda
  - [배치]   처리 엔진 → AWS Glue(Spark), Amazon EMR(Spark/Hadoop), AWS Batch
             오케스트레이터(언제 실행할지 지휘) → Airflow(MWAA), Step Functions

             


- 특징

   - 실시간 스트림 처리: Kinesis에서 들어오는 데이터를 계속 읽으면서 즉시 처리
   - Stateful Processing: 이전 이벤트 상태를 기억하면서 집계·판단 가능
   - Event Time 지원: 데이터가 실제 발생한 시간을 기준으로 처리 가능
   - Window 처리: 1분, 5분, 1시간 단위 집계 같은 작업에 강함
   - Checkpoint / 장애 복구: 처리 상태를 저장해서 장애 후 이어서 처리 가능
   - Exactly-once 처리 지원: 중복이나 누락을 최소화하는 신뢰성 높은 스트림 처리 가능
   - 대용량 처리에 적합: 지속적인 고속 이벤트 처리에 Lambda보다 유리
   - 복잡한 처리 가능: 필터링, 변환, 집계, 조인, 이상 탐지 등에 적합