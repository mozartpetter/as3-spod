package org.osflash.spod.builders
{
	import org.osflash.spod.SpodStatement;
	import org.osflash.spod.schema.SpodTableColumnSchema;
	import org.osflash.spod.schema.SpodTableSchema;
	import org.osflash.spod.schema.types.SpodSchemaType;

	import flash.errors.IllegalOperationError;
	import flash.utils.getQualifiedClassName;
	/**
	 * @author Simon Richardson - simon@ustwo.co.uk
	 */
	public class SelectAllStatementBuilder implements ISpodStatementBuilder
	{

		/**
		 * @private
		 */
		private var _schema : SpodTableSchema;
		
		/**
		 * @private
		 */
		private var _buffer : Vector.<String>;

		public function SelectAllStatementBuilder(schema : SpodTableSchema)
		{
			if(null == schema) throw new ArgumentError('SpodTableSchema can not be null');
			if(_schema.schemaType != SpodSchemaType.TABLE) throw new ArgumentError('Schema ' + 
																		'should be a table schema');
			_schema = schema;
			
			_buffer = new Vector.<String>();
		}

		public function build() : SpodStatement
		{
			if(_schema is SpodTableSchema)
			{
				const tableSchema : SpodTableSchema = SpodTableSchema(_schema);
				const columns : Vector.<SpodTableColumnSchema> = tableSchema.columns.reverse();
				const total : int = columns.length;
				
				if(total == 0) throw new IllegalOperationError('Invalid columns length');
				
				_buffer.length = 0;
				
				_buffer.push('SELECT ');
				
				for(var i : int = 0; i<total; i++)
				{
					const column : SpodTableColumnSchema = columns[i];
					const columnName : String = column.name;
					
					_buffer.push('`' + columnName + '`');
					_buffer.push(', ');
				}
				
				_buffer.pop();
				
				_buffer.push(' FROM ');
				_buffer.push('`' + _schema.name + '`');
				
				const statement : SpodStatement = new SpodStatement(tableSchema.type);
				
				// Make the query
				statement.query = _buffer.join('');
				
				return statement;
				
			} else throw new ArgumentError(getQualifiedClassName(_schema) + ' is not supported');
		}
	}
}
