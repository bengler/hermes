--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: hermes; Tablespace: 
--

CREATE TABLE messages (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    vendor_id text NOT NULL,
    profile text NOT NULL,
    status text NOT NULL,
    callback_url text,
    recipient_number text
);


ALTER TABLE public.messages OWNER TO hermes;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: hermes
--

CREATE SEQUENCE messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.messages_id_seq OWNER TO hermes;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hermes
--

ALTER SEQUENCE messages_id_seq OWNED BY messages.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: hermes; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO hermes;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: hermes
--

ALTER TABLE ONLY messages ALTER COLUMN id SET DEFAULT nextval('messages_id_seq'::regclass);


--
-- Name: messages_pkey; Type: CONSTRAINT; Schema: public; Owner: hermes; Tablespace: 
--

ALTER TABLE ONLY messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: hermes; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

