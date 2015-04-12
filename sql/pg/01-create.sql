create table vendor (
  code varchar(4) not null,
  name varchar(20) not null,
  full_name varchar(100) default null,

  constraint pk_vendor primary key (code),
  constraint uk1_vendor unique (name),
  constraint uk2_vendor unique (full_name)
);

begin transaction;

insert into vendor values ('tfa', 'TFA', 'The Flavor Apprentice');
insert into vendor values ('cap', 'Capella', 'Capella Flavors');
insert into vendor values ('fa', 'FlavourArt');
insert into vendor values ('inw', 'Inawera', 'Inawera Flavors');
insert into vendor values ('flv', 'Flavorah');

commit;

create table flavor (
  id bigserial not null,
  vendor_code varchar(4) not null,
  sku varchar(100) not null,
  name varchar(100) not null,
  msds_uri varchar(500) default null,

  constraint pk_flavor primary key (id),
  constraint uk1_flavor unique (vendor_code, name),
  constraint fk1_flavor foreign key (vendor_code) references vendor (code)
);

create table ingredient (
  id bigserial not null,
  name varchar(100) not null,
  cas_number varchar(10) default null,
  description varchar(500) default null,

  constraint pk_ingredient primary key (id),
  constraint uk1_ingredient unique (name),
  constraint uk2_ingredient unique (cas_number)
);

create table volume (
  id bigserial not null,
  description varchar(100) not null,
  volume_ml numeric(10, 2) not null,

  constraint pk_volume primary key (id),
  constraint uk1_volume unique (description),
  constraint uk2_volume unique (volume_ml)
);

create table flavor_volume (
  flavor_id bigint not null,
  volume_id bigint not null,
  price numeric(6, 2) not null,

  constraint pk_flavor_volume primary key (flavor_id, volume_id),
  constraint fk1_flavor_volume foreign key (flavor_id) references flavor (id),
  constraint fk2_flavor_volume foreign key (volume_id) references volume (id)
);

create table flavor_ingredient (
  flavor_id bigint not null,
  ingredient_id bigint not null,
  quantity varchar(100) not null,

  constraint pk_flavor_ingredient primary key (flavor_id, ingredient_id),
  constraint fk1_flavor_ingredient foreign key (flavor_id) references flavor (id),
  constraint fk2_flavor_ingredient foreign key (ingredient_id) references ingredient (id)
);