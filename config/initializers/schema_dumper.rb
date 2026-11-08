# The shared development database contains a connectivity probe unrelated to OneKare.
# Keep it out of db/schema.rb so new checkouts do not create it.
ActiveRecord::SchemaDumper.ignore_tables = [ "connection_test" ]
