/*
* Subject: IDS
* Project: Database SQL script
* Authors: Milan Hrabovsky (xhrabo15), Jakub Julius Smykal (xsmyka01)
* Date: 31.3.2022
*/

-- TABLE REMOVAL --

DROP TABLE prihlasenie;
DROP TABLE kradez;
DROP TABLE pokuta;
DROP TABLE zakaz;
DROP TABLE vozidlo;
DROP TABLE osoba;

-- TABLE CREATION --

CREATE TABLE osoba(
    rodne_cislo VARCHAR(11) PRIMARY KEY CHECK(REGEXP_LIKE(rodne_cislo, '^[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])/?[0-9]{3,4}$')) NOT NULL, --[YEAR][MONTH][DAY][?]optional[NUM]3x/4x
    meno VARCHAR(20) NOT NULL,
    priezvisko VARCHAR(20) NOT NULL,
    datum_narodenia DATE NOT NULL,
    bydlisko VARCHAR(50) NOT NULL,
    email VARCHAR(50) CHECK(REGEXP_LIKE(email, '^[a-zA-Z0-9\.]+\@[a-zA-Z]+\.[a-zA-Z]+$')) NOT NULL, --[NUM/LETTER/DOT][@][LETTER][.][LETTER]
    heslo VARCHAR(20) NOT NULL,
    opravnenie_vedenia_vozidla VARCHAR(30) NULL,
    skore_vodica NUMBER(10) DEFAULT 0,
    sluzobne_cislo NUMBER(10) NULL UNIQUE,
    hodnost VARCHAR(10) NULL,
    oddelenie VARCHAR(30) NULL,
    typ VARCHAR(10) CHECK (typ='občan' or typ='policajt') NOT NULL, --obcan cant have sluzobne_cislo, hodnost and oddelenie, policajt must have these parameters
    CONSTRAINT const_1 CHECK ((typ='občan' and sluzobne_cislo IS NULL and hodnost IS NULL and oddelenie is NULL)
                            or (typ='policajt' and sluzobne_cislo IS NOT NULL and hodnost IS NOT NULL and oddelenie is NOT NULL))
);

CREATE TABLE vozidlo(
    vin VARCHAR(17) PRIMARY KEY CHECK(REGEXP_LIKE(vin, '^[0-9][A-Z0-9]{10}[0-9]{6}$')), --[NUM][NUM/LETTER]10x[NUM]6x
    majitel REFERENCES osoba(rodne_cislo) NOT NULL,
    nazov VARCHAR(30) NOT NULL,
    typ_vozidla VARCHAR(20) NOT NULL,
    farba VARCHAR(20) NOT NULL,
    rok_vyroby NUMBER(4) NOT NULL,
    technicky_stav VARCHAR(20) NOT NULL,
    emisna_trieda VARCHAR(6) NOT NULL
);

CREATE TABLE prihlasenie(
    id_prihlasenia NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    prihlasene_vozidlo REFERENCES vozidlo(vin) NOT NULL,
    policajt REFERENCES osoba(rodne_cislo) NOT NULL,
    majitel REFERENCES osoba(rodne_cislo) NOT NULL,
    datum_prihlasenia DATE NOT NULL,
    spz VARCHAR(8) CHECK(REGEXP_LIKE(spz, '^[A-Z0-9]*[0-9][A-Z0-9]*$') and REGEXP_LIKE(spz, '^[^GOQW]*$')) NOT NULL --contains atleast one number, does not contain GOQW 
);

CREATE TABLE kradez(
    id_kradeze NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    ukradnute_vozidlo REFERENCES vozidlo(vin) NOT NULL,
    policajt REFERENCES osoba(rodne_cislo) NOT NULL,
    datum DATE NOT NULL,
    miesto VARCHAR(50) NOT NULL,
    vycislene_skody NUMBER(10) CHECK (vycislene_skody >= 0) NOT NULL, --positive number
    stav VARCHAR(14) CHECK (stav='nájdené' or stav='nenájdené') NOT NULL
);

CREATE TABLE pokuta(
    id_pokuty NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    vodic REFERENCES osoba(rodne_cislo) NOT NULL,
    policajt REFERENCES osoba(rodne_cislo) NOT NULL,
    pricina VARCHAR(50) NOT NULL,
    pokuta_body NUMBER(10) CHECK (pokuta_body >= 0) NOT NULL, --positive number
    body_doba_platnosti NUMBER(10) CHECK (body_doba_platnosti >= 0) NOT NULL, --positive number
    datum DATE NOT NULL,
    miesto VARCHAR(50) NOT NULL
);

CREATE TABLE zakaz(
    id_pokuty NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    vodic REFERENCES osoba(rodne_cislo) NOT NULL,
    policajt REFERENCES osoba(rodne_cislo) NOT NULL,
    pricina VARCHAR(50) NOT NULL,
    doba_trvania NUMBER(10) CHECK (doba_trvania >= 0) NOT NULL, --positive number
    datum DATE NOT NULL
);

-- TRIGGERS --

-- Adds score to osoba table from pokuta
CREATE OR REPLACE TRIGGER add_points
    BEFORE INSERT ON pokuta
    FOR EACH ROW
BEGIN
    UPDATE osoba
    SET skore_vodica = skore_vodica + :new.pokuta_body
    WHERE rodne_cislo = :new.vodic;
END;
/

-- Adds ban from driving to each person, that has more than 10 points for traffic violations
CREATE OR REPLACE TRIGGER add_ban
    AFTER INSERT on pokuta
    FOR EACH ROW
DECLARE
    skore NUMBER(10);
BEGIN
    SELECT skore_vodica 
        INTO skore
        FROM osoba
        WHERE rodne_cislo = :new.vodic;

    IF skore > 10
    THEN INSERT INTO zakaz(id_pokuty, vodic, policajt, pricina, doba_trvania, datum)
        VALUES (DEFAULT, :new.vodic, :new.policajt, 'príliš vysoké skóre vodiča', :new.body_doba_platnosti, :new.datum);
    END IF;
END;
/

-- DATA INSERTION --

-- OSOBA --
INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo, opravnenie_vedenia_vozidla,typ)
VALUES ('9510101572', 'Igor', 'Horný', date '1995-10-10', 'Purkyňova 93', 'igor@azet.sk', 123456, 'B1', 'občan');

INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo, opravnenie_vedenia_vozidla,sluzobne_cislo, hodnost, oddelenie, typ)
VALUES ('8503243325', 'Alfons', 'Dolný', date '1985-03-24', 'Purkyňova 93', 'alfons@azet.sk', 123456, 'A1,B1,B2', '0000000000', 'poručík', 'dopravné oddelenie', 'policajt');

INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo, opravnenie_vedenia_vozidla,sluzobne_cislo, hodnost, oddelenie, typ)
VALUES ('0107177562', 'Martin', 'Lavý', date '2001-07-17', 'Purkyňova 93', 'martin@azet.sk', 123456, 'A1,B1,B2', '0000000001', 'kapitán', 'dialničná polícia', 'policajt');

INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo, opravnenie_vedenia_vozidla,sluzobne_cislo, hodnost, oddelenie, typ)
VALUES ('0002092658', 'Adam', 'Pravý', date '2000-02-09', 'Purkyňova 93', 'adam@azet.cz', 123456, 'A1,B1,B2', '0000000002', 'poručík', 'oddelenie odcudzenia majetka', 'policajt');

INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo,sluzobne_cislo, hodnost, oddelenie, typ)
VALUES ('9904171158', 'Alexandra Saša', 'Stredná', date '1999-04-17', 'Purkyňova 93', 'alexandra.sasa@azet.sk', 123456, '0000000003', 'poručík', 'dopravné oddelenie', 'policajt');

INSERT INTO osoba(rodne_cislo, meno, priezvisko, datum_narodenia, bydlisko, email, heslo, opravnenie_vedenia_vozidla,typ)
VALUES ('9510101555', 'Michal', 'Predný', date '1995-10-10', 'Purkyňova 93', 'misko@azet.sk', 123456, 'B1', 'občan');
-- OSOBA --

-- VOZIDLO --
INSERT INTO vozidlo(vin, majitel, nazov, typ_vozidla, farba, rok_vyroby, technicky_stav, emisna_trieda)
VALUES ('3TMCZ5AN5GM015742', '9904171158', 'Škoda Fábia', 'hatchback', 'biela', 2003, 'vhodný', 'euro2');

INSERT INTO vozidlo(vin, majitel, nazov, typ_vozidla, farba, rok_vyroby, technicky_stav, emisna_trieda)
VALUES ('7SKCZ5AN5GM864566', '9904171158', 'Škoda Felicia', 'supersport', 'červena', 1995, 'vhodný', 'euro1');

INSERT INTO vozidlo(vin, majitel, nazov, typ_vozidla, farba, rok_vyroby, technicky_stav, emisna_trieda)
VALUES ('1TTCZ5FG5GM869876', '0002092658', 'Tatra 813', 'nákladné', 'hnedá', 1985, 'vhodný', 'euro0');

INSERT INTO vozidlo(vin, majitel, nazov, typ_vozidla, farba, rok_vyroby, technicky_stav, emisna_trieda)
VALUES ('9ARCZ5TR5FT985871', '0107177562', 'Alfa Romeo 166', 'sedan', 'modrá metalíza', 2003, 'nevhodný', 'euro4');

INSERT INTO vozidlo(vin, majitel, nazov, typ_vozidla, farba, rok_vyroby, technicky_stav, emisna_trieda)
VALUES ('9KGSW5TR5KG867461', '9510101555', 'Koenigsegg Agera RS', 'supersport', 'biela', 2014, 'vhodný', 'euro6');
-- VOZIDLO --

-- PRIHLASENIE --
INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '3TMCZ5AN5GM015742', '9904171158', '9904171158', date '2011-06-11', 'ABC896HF');

INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '7SKCZ5AN5GM864566', '9904171158', '9904171158', date '2016-09-12', 'ABC216HA');

INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '1TTCZ5FG5GM869876', '9904171158', '0002092658', date '2015-04-25', 'TAT813RA');

INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '9ARCZ5TR5FT985871', '9904171158', '0107177562', date '2021-03-18', 'SHB924AZ');

INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '9KGSW5TR5KG867461', '9904171158', '0002092658', date '2018-10-10', 'ASD666FD');

INSERT INTO prihlasenie(id_prihlasenia, prihlasene_vozidlo, policajt, majitel, datum_prihlasenia, spz)
VALUES (DEFAULT, '9KGSW5TR5KG867461', '9904171158', '0107177562', date '2020-09-17', 'ASD876FD');
-- PRIHLASENIE --

-- KRADEZ --
INSERT INTO kradez(id_kradeze, ukradnute_vozidlo, policajt, datum, miesto, vycislene_skody, stav)
VALUES (DEFAULT, '9KGSW5TR5KG867461', '9904171158', date '2019-10-10', 'Purkyňova 93', 1000000, 'nájdené');

INSERT INTO kradez(id_kradeze, ukradnute_vozidlo, policajt, datum, miesto, vycislene_skody, stav)
VALUES (DEFAULT, '9KGSW5TR5KG867461', '0107177562', date '2021-04-01', 'pred policajnou stanicou', 900000, 'nenájdené');

INSERT INTO kradez(id_kradeze, ukradnute_vozidlo, policajt, datum, miesto, vycislene_skody, stav)
VALUES (DEFAULT, '9ARCZ5TR5FT985871', '9904171158', date '2021-02-11', 'pri internáte v Brne', 10, 'nenájdené');

INSERT INTO kradez(id_kradeze, ukradnute_vozidlo, policajt, datum, miesto, vycislene_skody, stav)
VALUES (DEFAULT, '1TTCZ5FG5GM869876', '0002092658', date '2017-07-04', 'vojenská základňa', 25000, 'nenájdené');
-- KRADEZ --

-- POKUTA --
INSERT INTO pokuta(id_pokuty, vodic, policajt, pricina, pokuta_body, body_doba_platnosti, datum, miesto)
VALUES (DEFAULT, '9510101555', '9904171158', 'nabural', 10, 9999, date '2020-01-22', 'za policajnou stanicou');
INSERT INTO pokuta(id_pokuty, vodic, policajt, pricina, pokuta_body, body_doba_platnosti, datum, miesto)
VALUES (DEFAULT, '9510101555', '9904171158', 'nabural', 10, 9999, date '2020-01-22', 'pred policajnou stanicou');
INSERT INTO pokuta(id_pokuty, vodic, policajt, pricina, pokuta_body, body_doba_platnosti, datum, miesto)
VALUES (DEFAULT, '0107177562', '9904171158', 'prekročenie rýchlosti', 10, 9999, date '2000-07-08', 'za policajnou stanicou');
-- POKUTA --

-- ZAKAZ --
INSERT INTO zakaz(id_pokuty, vodic, policajt, pricina, doba_trvania, datum)
VALUES (DEFAULT, '9510101555', '9904171158', 'nabúral vela krat', 9999, date '2020-02-23');
INSERT INTO zakaz(id_pokuty, vodic, policajt, pricina, doba_trvania, datum)
VALUES (DEFAULT, '0107177562', '9904171158', 'vysoká rýchlosť', 9999, date '2000-07-10');
-- ZAKAZ --

-- SELECTS --

-- Finds all vehicle registrations, where car was built after year 2000
SELECT nazov, vin, rok_vyroby, datum_prihlasenia, spz
    FROM vozidlo V, prihlasenie P
    WHERE V.vin = P.prihlasene_vozidlo AND V.rok_vyroby > 2000;

-- Finds all stolen cars, which were not retrieved
SELECT id_kradeze, nazov, miesto, datum
    FROM vozidlo V, kradez K
    WHERE V.vin = K.ukradnute_vozidlo AND K.stav = 'nenájdené';

-- Finds all people, who own a car but are forbidden from driving
SELECT DISTINCT rodne_cislo, meno, priezvisko, doba_trvania
    FROM osoba O, vozidlo V, zakaz Z
    WHERE O.rodne_cislo = V.majitel AND O.rodne_cislo = Z.vodic;

-- Counts number of vehicles (greater than 0) each car owner owns
SELECT DISTINCT rodne_cislo, meno, priezvisko, COUNT(*) pocet_vozidiel
    FROM osoba O, vozidlo V
    WHERE O.rodne_cislo = V.majitel
    GROUP BY rodne_cislo, meno, priezvisko;

-- Counts number of thefts and average damage cost per theft registered by each police officer
SELECT DISTINCT rodne_cislo, meno, priezvisko, COUNT(*) pocet_kradezi, AVG(vycislene_skody) priemerna_skoda
    FROM osoba O, kradez K
    WHERE O.rodne_cislo = K.policajt
    GROUP BY rodne_cislo, meno, priezvisko;

-- Finds all people, who never got ticket
SELECT rodne_cislo, meno, priezvisko
    FROM osoba O
    WHERE NOT EXISTS( SELECT *
        FROM pokuta P
        WHERE O.rodne_cislo = P.vodic);

-- Finds all police officers who are in 'dopravné oddelenie' department and own a car
SELECT rodne_cislo, meno, priezvisko
    FROM osoba
    WHERE rodne_cislo IN( SELECT rodne_cislo
        FROM osoba O, vozidlo V
        WHERE O.typ = 'policajt' AND O.rodne_cislo = V.majitel AND O.oddelenie = 'dopravné oddelenie');


-- PROCEDURES --

-- Returns percentage of cars, which were recovered after being stolen
CREATE OR REPLACE PROCEDURE recovered_perc
    IS
        najdene_vozidla NUMBER;
        pocet_vozidiel NUMBER;
        stav_vozidla kradez.stav%TYPE;
        CURSOR c_vozidlo IS
            SELECT stav
                FROM kradez;
            
BEGIN
    najdene_vozidla := 0;
    SELECT COUNT(*)
        INTO pocet_vozidiel
        FROM kradez;
    
    OPEN c_vozidlo;
    LOOP
        FETCH c_vozidlo
            INTO stav_vozidla;
        EXIT WHEN c_vozidlo%NOTFOUND;
        IF stav_vozidla = 'nájdené'
            THEN najdene_vozidla := najdene_vozidla + 1;
        END IF;
    END LOOP;
    CLOSE c_vozidlo;

    DBMS_OUTPUT.PUT_LINE(najdene_vozidla/pocet_vozidiel * 100 || '% ukradnutých vozidiel bolo nájdených.');

EXCEPTION
    WHEN ZERO_DIVIDE
        THEN DBMS_OUTPUT.PUT_LINE('Žiadne vozidlá neboli ukradnuté');
END;
/

-- Finds car's name and production year based on inserted SPZ
CREATE OR REPLACE PROCEDURE find_car(
    v_spz VARCHAR
    )
    IS
        v_nazov vozidlo.nazov%TYPE;
        v_rok vozidlo.rok_vyroby%TYPE;
BEGIN
    SELECT v.nazov, v.rok_vyroby
        INTO v_nazov, v_rok
        FROM prihlasenie P, vozidlo V
        WHERE P.prihlasene_vozidlo = V.vin AND P.spz = v_spz;

    DBMS_OUTPUT.PUT_LINE(v_rok || ' ' || v_nazov);

EXCEPTION
    WHEN NO_DATA_FOUND
        THEN DBMS_OUTPUT.PUT_LINE('Vozidlo s špz ' || v_spz || ' neexistuje v databázi.');
END;
/

-- Execute recovered_perc procedure => percentage of stolen car recovered (25%)
EXEC recovered_perc;

-- Execute find_car procedure => 1. successful, 2. failed
EXEC find_car ('TAT813RA');
EXEC find_car ('BMW46M3E');

-- EXPLAIN PLAN --

EXPLAIN PLAN FOR
    SELECT DISTINCT rodne_cislo, meno, priezvisko, COUNT(*) pocet_kradezi, AVG(vycislene_skody) priemerna_skoda
    FROM osoba O, kradez K
    WHERE O.rodne_cislo = K.policajt
    GROUP BY rodne_cislo, meno, priezvisko;

SELECT *
    FROM TABLE(DBMS_XPLAN.DISPLAY());

CREATE INDEX policajt_index
    ON kradez(policajt);

EXPLAIN PLAN FOR
    SELECT DISTINCT rodne_cislo, meno, priezvisko, COUNT(*) pocet_kradezi, AVG(vycislene_skody) priemerna_skoda
    FROM osoba O, kradez K
    WHERE O.rodne_cislo = K.policajt
    GROUP BY rodne_cislo, meno, priezvisko;

SELECT *
    FROM TABLE(DBMS_XPLAN.DISPLAY());

-- ACCESS RIGHTS --

GRANT ALL ON prihlasenie TO xsmyka01;
GRANT ALL ON kradez TO xsmyka01;
GRANT ALL ON pokuta TO xsmyka01;
GRANT ALL ON zakaz TO xsmyka01;
GRANT ALL ON vozidlo TO xsmyka01;
GRANT ALL ON osoba TO xsmyka01;


-- MATERIALIZED VIEW --

DROP MATERIALIZED VIEW not_found;

CREATE MATERIALIZED VIEW not_found AS
    SELECT *
        FROM kradez
        WHERE stav = 'nenájdené';

GRANT ALL ON not_found TO xsmyka01;

-- TEST MATERIALIZED VIEW ON SECOND ACC-- 
/*
SELECT *
    FROM xhrabo15.not_found;

INSERT INTO xhrabo15.kradez(id_kradeze, ukradnute_vozidlo, policajt, datum, miesto, vycislene_skody, stav)
VALUES (DEFAULT, '7SKCZ5AN5GM864566', '0002092658', date '2022-04-28', 'základná škola v piešťanoch', 200, 'nenájdené');

SELECT *
    FROM xhrabo15.not_found;
*/