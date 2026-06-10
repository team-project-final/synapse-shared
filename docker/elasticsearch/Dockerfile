# 커스텀 Elasticsearch — analysis-nori 플러그인 포함 (gitops#174 / 검색 P3)
# knowledge가 notes-v1 인덱스를 nori_tokenizer로 생성하므로 nori 필수.
# stock 이미지엔 nori 미포함 → "Unknown tokenizer type [nori_tokenizer]" 500.
FROM docker.elastic.co/elasticsearch/elasticsearch:9.2.1
RUN bin/elasticsearch-plugin install --batch analysis-nori
