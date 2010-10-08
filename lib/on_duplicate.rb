module ActiveRecord
  class Base
    def self.od_update(args)
      cattr_accessor :on_duplicate_update
      self.on_duplicate_update = (args.respond_to?('each')?args:[args])
    end

    def self.od_replace(args)
      cattr_accessor :on_duplicate_replace
      self.on_duplicate_replace = (args.respond_to?('each')?args:[args])
    end
    
    def save
      if (self.respond_to?('on_duplicate_replace') or self.respond_to?('on_duplicate_update')) and self.new_record?
        od_create_or_update
      else
        create_or_update
      end
    end

    private
    
    def od_create_or_update()
      if self.id.nil? && connection.prefetch_primary_key?(self.class.table_name)
        self.id = connection.next_sequence_value(self.class.sequence_name)
      end

      quoted_attributes = attributes_with_quotes
      if quoted_attributes.empty?
        statement = connection.empty_insert_statement(self.class.table_name)
      else
        statement = "INSERT INTO #{self.class.quoted_table_name} " +
          "(#{quoted_column_names.join(', ')}) " +
          "VALUES(#{quoted_attributes.values.join(', ')})"
        ondupli = ""
        if self.respond_to?('on_duplicate_replace')
          self.on_duplicate_replace.each do |item|
            if item!='' and self.changed.include?(item.to_s)
              ondupli +=", `#{item}`=#{quoted_attributes[item.to_s]}"
            end
          end
        end
        if self.respond_to?('on_duplicate_update')
          self.on_duplicate_update.each do |item|
            if item!='' and self.changed?
              if quoted_attributes[item.to_s]!='NULL'
                ondupli +=", `#{item}`=`#{item}`+#{quoted_attributes[item.to_s]}"
              end
            end
          end
        end
        if ondupli!=''
          statement += " ON DUPLICATE KEY UPDATE #{ondupli.slice(1..-1)}"
        end
      end
      connection.insert_sql(statement, "#{self.class.name} Create")
    end
  end
end