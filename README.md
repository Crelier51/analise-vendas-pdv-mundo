# 📈 Análise Inteligente de Vendas do PDV Mundo

Este projeto apresenta uma solução completa de análise de dados para identificar oportunidades de aumento de vendas no portfólio, utilizando automação de dados e dashboards interativos no Looker Studio.

---

## 🚀 Objetivo

Extrair insights valiosos a partir dos dados de vendas do **App PDV Mundo**, automatizando as etapas de:
- Coleta e tratamento de dados via query SQL.
- Modelagem e análise focada em oportunidades de negócio.
- Visualização em dashboard interativo (Looker Studio) para a tomada de decisões.

---

## 📐 Arquitetura da Solução

A solução é baseada em três etapas principais:
1.  **Coleta e Tratamento de Dados:** Uma query SQL (salva em `analise/query_tratamento_pdv.sql`) extrai e pré-processa os dados do PDV Mundo.
2.  **Modelagem e Análise:** O Looker Studio é usado para criar métricas e filtros que revelam oportunidades de aumento de vendas.
3.  **Visualização:** O dashboard no Looker Studio apresenta os insights de forma clara, ajudando a identificar o desempenho por produto, região e período.

---

## 🗂️ Estrutura do Projeto

```plaintext
projeto-vendas-pdv/
├── analise/
│   └── query_tratamento_pdv.sql      # Sua query para tratamento de dados.
├── dashboard/
│   └── dashboard_looker.pdf          # PDF do dashboard do Looker Studio.
├── .gitignore                        # Arquivos ignorados pelo Git.
└── README.md                         # Este documento.