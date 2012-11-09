Pebblebed.config do
  service :checkpoint, :version => 1
  service :grove, :version => 1
end

host = case ENV['RACK_ENV']
 when 'staging' then 'hermes.staging.o5.no'.freeze
 when 'production' then 'hermes.o5.no'.freeze
 else 'hermes.dev'.freeze
end

Pebblebed.config do
  host host
end
