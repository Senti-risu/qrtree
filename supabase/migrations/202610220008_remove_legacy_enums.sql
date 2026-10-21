begin;

do $$
declare
  enum_name text;
  enum_oid oid;
  column_record record;
  policy_record record;
  default_expression text;
  default_value text;
  policy_using text;
  policy_check text;
  policy_roles text;
  policy_sql text;
  policy_statements text[];
begin
  foreach enum_name in array array[
    'plant_type_enum',
    'health_status_enum',
    'growth_stage_enum',
    'qr_status_enum'
  ]
  loop
    select t.oid into enum_oid
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = enum_name
      and t.typtype = 'e';

    if enum_oid is null then
      continue;
    end if;

    for column_record in
      select
        n.nspname as schema_name,
        c.relname as table_name,
        a.attname as column_name,
        a.attrelid as table_oid,
        a.attnum as column_number
      from pg_attribute a
      join pg_class c on c.oid = a.attrelid
      join pg_namespace n on n.oid = c.relnamespace
      where a.atttypid = enum_oid
        and a.attnum > 0
        and not a.attisdropped
        and c.relkind in ('r', 'p')
    loop
      default_expression := null;
      default_value := null;
      policy_statements := array[]::text[];

      -- PostgreSQL does not allow a column type change while a row-level
      -- security policy depends on that column. Save those policies, remove
      -- them for the conversion, then restore the same permissions after it.
      for policy_record in
        select p.*
        from pg_policy p
        where p.polrelid = column_record.table_oid
          and exists (
            select 1
            from pg_depend d
            where d.classid = 'pg_policy'::regclass
              and d.objid = p.oid
              and d.refobjid = column_record.table_oid
              and d.refobjsubid = column_record.column_number
          )
      loop
        policy_using := pg_get_expr(policy_record.polqual, policy_record.polrelid);
        policy_check := pg_get_expr(
          policy_record.polwithcheck,
          policy_record.polrelid
        );
        -- A rendered policy can include an explicit enum cast. Rewrite that
        -- cast to text so the restored policy no longer depends on the enum.
        policy_using := replace(
          replace(policy_using, format('::public.%I', enum_name), '::text'),
          format('::%I', enum_name),
          '::text'
        );
        policy_check := replace(
          replace(policy_check, format('::public.%I', enum_name), '::text'),
          format('::%I', enum_name),
          '::text'
        );
        select string_agg(
          case
            when role_id = 0 then 'public'
            else quote_ident(pg_get_userbyid(role_id))
          end,
          ', ' order by role_id
        ) into policy_roles
        from unnest(policy_record.polroles) as role_ids(role_id);

        policy_sql := format(
          'create policy %I on %I.%I as %s for %s to %s',
          policy_record.polname,
          column_record.schema_name,
          column_record.table_name,
          case
            when policy_record.polpermissive then 'permissive'
            else 'restrictive'
          end,
          case policy_record.polcmd
            when 'r' then 'select'
            when 'a' then 'insert'
            when 'w' then 'update'
            when 'd' then 'delete'
            else 'all'
          end,
          coalesce(policy_roles, 'public')
        );
        if policy_using is not null then
          policy_sql := policy_sql || format(' using (%s)', policy_using);
        end if;
        if policy_check is not null then
          policy_sql := policy_sql || format(' with check (%s)', policy_check);
        end if;
        policy_statements := array_append(policy_statements, policy_sql);

        execute format(
          'drop policy %I on %I.%I',
          policy_record.polname,
          column_record.schema_name,
          column_record.table_name
        );
      end loop;

      select pg_get_expr(d.adbin, d.adrelid)
      into default_expression
      from pg_attrdef d
      where d.adrelid = column_record.table_oid
        and d.adnum = column_record.column_number;

      if default_expression is not null then
        execute format('select (%s)::text', default_expression)
          into default_value;
        execute format(
          'alter table %I.%I alter column %I drop default',
          column_record.schema_name,
          column_record.table_name,
          column_record.column_name
        );
      end if;

      execute format(
        'alter table %I.%I alter column %I type text using %I::text',
        column_record.schema_name,
        column_record.table_name,
        column_record.column_name,
        column_record.column_name
      );

      if default_expression is not null then
        execute format(
          'alter table %I.%I alter column %I set default %L',
          column_record.schema_name,
          column_record.table_name,
          column_record.column_name,
          default_value
        );
      end if;

      foreach policy_sql in array policy_statements
      loop
        execute policy_sql;
      end loop;
    end loop;

    execute format('drop type public.%I', enum_name);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
commit;
