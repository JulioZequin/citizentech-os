"""
Refresca - Página de alerta de calor (CitizenTech)
Mostra o índice de calor atual na Vila Mariana, o nível de alerta e os
Pontos Refresca mais próximos, para trabalhadores de rua.
Temperatura e umidade: API pública Open-Meteo (open-meteo.com).
Índice de calor: fórmula da NOAA. Pontos Refresca: dados SIMULADOS.
"""
import os
import requests
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "Refresca")
CIDADE = os.getenv("CIDADE", "Vila Mariana, São Paulo")
LATITUDE = os.getenv("LATITUDE", "-23.59")
LONGITUDE = os.getenv("LONGITUDE", "-46.63")

# Dados simulados (comércios fictícios)
PONTOS_REFRESCA = [
    {"nome": "Padaria Exemplo - Rua Domingos de Morais",
     "agua": True, "sombra": True, "banheiro": True},
    {"nome": "Mercadinho Exemplo - perto do Metrô Ana Rosa",
     "agua": True, "sombra": True, "banheiro": False},
    {"nome": "Banca Exemplo - perto do Metrô Vila Mariana",
     "agua": True, "sombra": False, "banheiro": False},
]


def obter_clima():
    """Busca temperatura (°C) e umidade (%) atuais na Open-Meteo."""
    try:
        resposta = requests.get(
            "https://api.open-meteo.com/v1/forecast",
            params={"latitude": LATITUDE, "longitude": LONGITUDE,
                    "current": "temperature_2m,relative_humidity_2m"},
            timeout=5,
        )
        resposta.raise_for_status()
        atual = resposta.json()["current"]
        return atual["temperature_2m"], atual["relative_humidity_2m"]
    except Exception:
        return None, None


def indice_calor(temp_c, umidade):
    """Índice de calor (sensação térmica) pela fórmula da NOAA, em °C."""
    t = temp_c * 9 / 5 + 32          # a fórmula trabalha em Fahrenheit
    rh = umidade
    ic = 0.5 * (t + 61.0 + (t - 68.0) * 1.2 + rh * 0.094)
    if (ic + t) / 2 >= 80:           # acima de ~27 °C usa a regressão completa
        ic = (-42.379 + 2.04901523 * t + 10.14333127 * rh
              - 0.22475541 * t * rh - 0.00683783 * t * t
              - 0.05481717 * rh * rh + 0.00122874 * t * t * rh
              + 0.00085282 * t * rh * rh - 0.00000199 * t * t * rh * rh)
    return (ic - 32) * 5 / 9


def nivel_alerta(ic):
    """Níveis da Refresca: normal < 27 °C <= atenção < 32 °C <= perigo."""
    if ic is None:
        return {"nivel": "SEM DADOS", "cor": "#555555",
                "mensagem": "Não foi possível obter o clima agora."}
    if ic >= 32:
        return {"nivel": "PERIGO", "cor": "#b00020",
                "mensagem": "Calor perigoso: faça pausas na sombra, beba água com frequência e procure um Ponto Refresca."}
    if ic >= 27:
        return {"nivel": "ATENÇÃO", "cor": "#8a5200",
                "mensagem": "Calor forte: hidrate-se e evite o sol direto nas horas mais quentes."}
    return {"nivel": "NORMAL", "cor": "#1b5e20",
            "mensagem": "Sem risco de calor no momento."}


def dados_atuais():
    temp, umidade = obter_clima()
    ic = indice_calor(temp, umidade) if temp is not None else None
    return temp, umidade, ic, nivel_alerta(ic)


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
    .ic { font-size: 48px; font-weight: bold; margin: 8px 0; }
    li { margin: 10px 0; }
    small { color: #444; }
  </style>
</head>
<body>
  <main>
    <h1>{{ app_name }}</h1>
    <p>Alerta de calor para quem trabalha na rua.</p>
    <section class="alerta">
      <div>{{ cidade }} agora</div>
      <div>Sensação térmica (índice de calor)</div>
      <div class="ic">{{ ic_texto }}</div>
      <div>Temperatura {{ temp_texto }} · Umidade {{ umidade_texto }}</div>
      <p><strong>{{ alerta.nivel }}</strong><br>{{ alerta.mensagem }}</p>
    </section>
    <h2>Pontos Refresca</h2>
    <ul>
      {% for p in pontos %}
      <li><strong>{{ p.nome }}</strong><br>
        {{ "Água" if p.agua }}{{ " · Sombra" if p.sombra }}{{ " · Banheiro" if p.banheiro }}
      </li>
      {% endfor %}
    </ul>
    <small>Clima: Open-Meteo. Índice de calor: fórmula da NOAA.
    Pontos Refresca: dados simulados.</small>
  </main>
</body>
</html>
"""


@app.route("/")
def index():
    temp, umidade, ic, alerta = dados_atuais()
    return render_template_string(
        PAGINA, app_name=APP_NAME, cidade=CIDADE, alerta=alerta,
        pontos=PONTOS_REFRESCA,
        ic_texto=f"{ic:.0f} °C" if ic is not None else "--",
        temp_texto=f"{temp:.0f} °C" if temp is not None else "--",
        umidade_texto=f"{umidade:.0f}%" if umidade is not None else "--")


@app.route("/api/status")
def api_status():
    temp, umidade, ic, alerta = dados_atuais()
    return jsonify({"local": CIDADE, "temperatura": temp, "umidade": umidade,
                    "indiceCalor": round(ic, 1) if ic is not None else None,
                    **alerta, "pontosRefresca": PONTOS_REFRESCA})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})