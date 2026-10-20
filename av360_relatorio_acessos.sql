-- ============================================================
-- Avaliação 360º — quem participa da 360 mas ainda NÃO consegue entrar
-- Rode no SQL Editor depois de av360_import.sql. Só leitura.
--
-- sem_login_no_portal = precisa criar a conta (admin_gestores.html ou
--   Authentication → Add user) com ESSE MESMO e-mail. É pelo e-mail
--   que o portal descobre quem a pessoa é na 360.
-- sem_perfil = a conta existe mas não tem linha em "profiles"
--   (a pessoa loga e é barrada no portal).
-- sem_pessoa = não foi ligado automaticamente a ninguém de "pessoas"
--   (não impede o acesso; só não aparece cruzado com PDI/Trajetória).
-- ============================================================
select m.name, m.email, m.unit,
       (u.id is null)  as sem_login_no_portal,
       (u.id is not null and p.id is null) as sem_perfil,
       (m.pessoa_id is null) as sem_pessoa
from public.av360_managers m
left join auth.users u on lower(trim(u.email)) = lower(trim(m.email))
left join public.profiles p on p.id = u.id
where u.id is null or p.id is null or m.pessoa_id is null
order by sem_login_no_portal desc, m.name;
