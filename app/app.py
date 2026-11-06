"""
CitizenTech - Calor Extremo
Mostra a temperatura atual da cidade, o nível de alerta e pontos de hidratação.
Fonte da temperatura: API pública Open-Meteo (open-meteo.com).
Pontos de hidratação: dados SIMULADOS para o protótipo.
"""
import os
import requests
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "CitizenTech Calor Extremo")
CIDADE = os.getenv("CIDADE", "São Paulo")
LATITUDE = os.getenv("LATITUDE", "-23.55")
LONGITUDE = os.getenv("LONGITUDE", "-46.63")

# Dados simulados (não são pontos reais)
PONTOS_HIDRATACAO = [
    {"nome": "Praça da Sé - bebedouro público", "horario": "24 horas"},
    {"nome": "Estação Paulista - ponto de água", "horario": "6h às 22h"},
    {"nome": "Parque Ibirapuera - portão 3", "horario": "5h às 0h"},
]


def obter_temperatura():
    """Busca a temperatura atual na Open-Meteo. Retorna None se falhar."""
    try:
        resposta = requests.get(
            "https://api.open-meteo.com/v1/forecast",
            params={"latitude": LATITUDE, "longitude": LONGITUDE,
                    "current": "temperature_2m"},
            timeout=5,
        )
        resposta.raise_for_status()
        return resposta.json()["current"]["temperature_2m"]
    except Exception:
        return None


def nivel_alerta(temp):
    """Classifica o risco de acordo com a temperatura."""
    if temp is None:
        return {"nivel": "SEM DADOS", "cor": "#555555",
                "mensagem": "Não foi possível obter a temperatura agora."}
    if temp >= 35:
        return {"nivel": "ALERTA", "cor": "#b00020",
                "mensagem": "Calor extremo: beba água, evite o sol entre 10h e 16h e cuide dos idosos."}
    if temp >= 30:
        return {"nivel": "ATENÇÃO", "cor": "#b35c00",
                "mensagem": "Muito calor: hidrate-se e procure sombra."}
    return {"nivel": "NORMAL", "cor": "#1b5e20",
            "mensagem": "Temperatura sem risco no momento."}


PAGINA = """
<!doctype html>
<html lang="pt-br">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ app_name }}</title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 20px; margin: 0;
           background: #fafafa; color: #111; }
    main { max-width: 640px; margin: 0 auto; padding: 16px; }
    .alerta { background: {{ alerta.cor }}; color: #fff; padding: 20px;
              border-radius: 12px; }
    .temp { font-size: 48px; font-weight: bold; margin: 8px 0; }
    li { margin: 8px 0; }
    small { color: #444; }
  </style>
</head>
<body>
  <main>
    <h1>{{ app_name }}</h1>
    <section class="alerta">
      <div>{{ cidade }} agora</div>
      <div class="temp">{{ temp_texto }}</div>
      <strong>{{ alerta.nivel }}</strong>
      <p>{{ alerta.mensagem }}</p>
    </section>
    <h2>Pontos de hidratação</h2>
    <ul>
      {% for p in pontos %}
      <li><strong>{{ p.nome }}</strong> - {{ p.horario }}</li>
      {% endfor %}
    </ul>
    <small>Temperatura: Open-Meteo. Pontos de hidratação: dados simulados.</small>
  </main>
</body>
</html>
"""


@app.route("/")
def index():
    temp = obter_temperatura()
    temp_texto = f"{temp:.0f} °C" if temp is not None else "--"
    return render_template_string(
        PAGINA, app_name=APP_NAME, cidade=CIDADE, temp_texto=temp_texto,
        alerta=nivel_alerta(temp), pontos=PONTOS_HIDRATACAO)


@app.route("/api/status")
def api_status():
    temp = obter_temperatura()
    return jsonify({"cidade": CIDADE, "temperatura": temp,
                    **nivel_alerta(temp), "pontos_hidratacao": PONTOS_HIDRATACAO})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})