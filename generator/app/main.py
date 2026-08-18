# 엔트리 진입
from app.domain import ecommerce
from faker import Faker
import json

fake = Faker("ko_KR")

def run():
    log = ecommerce.generate(fake, timezone_name="", envrionment="", run_id="")
    # 정상 실행 종료 표시
    
    print(json.dumps(log, ensure_ascii=False))
    
    return 0
    

if __name__ == '__main__' :
    
    # run() 반환값을 프로세스 종료 코드로 활용
    raise SystemExit(run())