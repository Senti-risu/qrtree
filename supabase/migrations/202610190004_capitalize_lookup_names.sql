begin;

-- Match the application's capitalization without lowercasing acronyms or names.
create or replace function public.capitalize_display_words(p_text text)
returns text language plpgsql immutable strict set search_path = public as $$
declare
  result text := '';
  current_character text;
  word_start boolean := true;
  char_index integer;
begin
  for char_index in 1..char_length(p_text) loop
    current_character := substr(p_text, char_index, 1);
    result := result || case when word_start then upper(current_character) else current_character end;
    word_start := current_character ~ '[[:space:]''’\-]';
  end loop;
  return result;
end;
$$;

create or replace function public.capitalize_lookup_display_names()
returns trigger language plpgsql set search_path = public as $$
declare
  payload jsonb := to_jsonb(new);
  column_name text;
begin
  foreach column_name in array tg_argv loop
    if payload ->> column_name is not null then
      payload := jsonb_set(payload, array[column_name],
        to_jsonb(public.capitalize_display_words(payload ->> column_name)));
    end if;
  end loop;
  new := jsonb_populate_record(new, payload);
  return new;
end;
$$;

-- Only human-readable text columns. Never change scientific names, enum values,
-- usernames, passwords, QR payloads, IDs, URLs, or free-text paragraphs.
do $$
declare
  item record;
  field text;
  fields text[];
  assignments text;
  arguments text;
begin
  for item in select * from (values
    ('campus', array['campus_name']),
    ('college', array['college_name']),
    ('town', array['town_name']),
    ('barangay', array['barangay_name']),
    ('plant_classification', array['common_name', 'plant_type']),
    ('growth_status', array['growth_stage']),
    ('health_status', array['status_name'])
  ) as configuration(table_name, columns) loop
    fields := array[]::text[];
    assignments := '';
    arguments := '';
    foreach field in array item.columns loop
      if exists (
        select 1 from pg_attribute a join pg_type t on t.oid = a.atttypid
        where a.attrelid = to_regclass('public.' || item.table_name)
          and a.attname = field and not a.attisdropped and t.typcategory = 'S'
      ) then
        fields := array_append(fields, field);
        assignments := assignments || case when assignments = '' then '' else ', ' end ||
          format('%I = public.capitalize_display_words(%I)', field, field);
        arguments := arguments || case when arguments = '' then '' else ', ' end || format('%L', field);
      end if;
    end loop;
    if cardinality(fields) > 0 then
      execute format('update public.%I set %s', item.table_name, assignments);
      execute format('drop trigger if exists capitalize_lookup_names on public.%I', item.table_name);
      execute format('create trigger capitalize_lookup_names before insert or update on public.%I
        for each row execute function public.capitalize_lookup_display_names(%s)', item.table_name, arguments);
    end if;
  end loop;
end;
$$;

commit;
