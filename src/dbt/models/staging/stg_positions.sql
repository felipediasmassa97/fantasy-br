{{ config(materialized='view') }}

select
    id,
    case nome
        when 'Goleiro' then 'GK'
        when 'Lateral' then 'FB'
        when 'Zagueiro' then 'CB'
        when 'Meia' then 'MD'
        when 'Atacante' then 'AT'
        when 'Técnico' then 'HC'
    end as abbreviation,
    nome as name
from {{ source('cartola', 'raw_positions') }}
