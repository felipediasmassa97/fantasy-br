{% macro dvs(z_score_column, availability_column, gamma=0.3) %}
{{ z_score_column }} * (1 - (1 - {{ availability_column }}) * {{ gamma }})
{% endmacro %}
