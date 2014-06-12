module CfDeployer
  class Hook
    def initialize(name, body)
      @name = name
      @body = body
    end

    def run(context)
      case @body
      when Hash
        if @body[:file]
          file = File.expand_path(@body[:file], context[:config_dir])
          execute(File.read(file), context, @body[:timeout])
        else
          execute(@body[:code], context, @body[:timeout])
        end
      when String
        execute(@body, context)
      end
    end

    private
    def execute(hook, context, timeout = nil)
      CfDeployer::Log.info("Running hook #{@name}")
      context = context.dup
      timeout = timeout || Defaults::Timeout
      Timeout.timeout(timeout.to_f) do
        begin
          eval(hook, binding)
        rescue SyntaxError, NoMethodError, ApplicationError => e
          error_document context, hook
          raise e
        end
      end
    end

    def error_document context, hook
      pp context
      puts '=' * 80
      puts hook
      puts '=' * 80
    end
  end
end
