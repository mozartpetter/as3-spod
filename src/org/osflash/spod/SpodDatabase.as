package org.osflash.spod
{
	import org.osflash.signals.IPrioritySignal;
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;
	import org.osflash.signals.natives.NativeSignal;
	import org.osflash.spod.builders.CreateStatementBuilder;
	import org.osflash.spod.builders.ISpodStatementBuilder;
	import org.osflash.spod.errors.SpodError;
	import org.osflash.spod.errors.SpodErrorEvent;
	import org.osflash.spod.schema.SpodTableColumnSchema;
	import org.osflash.spod.schema.SpodTableSchema;
	import org.osflash.spod.types.SpodTypes;
	import org.osflash.spod.utils.getClassNameFromQname;

	import flash.data.SQLColumnSchema;
	import flash.data.SQLSchemaResult;
	import flash.data.SQLTableSchema;
	import flash.errors.IllegalOperationError;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	import flash.utils.getQualifiedClassName;
	/**
	 * @author Simon Richardson - simon@ustwo.co.uk
	 */
	public class SpodDatabase
	{
		
		/**
		 * @private
		 */
		private var _name : String;
		
		/**
		 * @private
		 */
		private var _manager : SpodManager;
		
		/**
		 * @private
		 */
		private var _tables : Dictionary;
		
		/**
		 * @private
		 */
		private var _createTableSignal : ISignal;
		
		private var _nativeSQLErrorEventSignal : IPrioritySignal;
		
		private var _nativeSQLEventSchemaSignal : IPrioritySignal;
				
		public function SpodDatabase(name : String, manager : SpodManager)
		{
			if(null == name) throw new ArgumentError('Name can not be null');
			if(name.length < 1) throw new ArgumentError('Name can not be emtpy');
			if(null == manager) throw new ArgumentError('Manager can not be null');
			
			_name = name;
			_manager = manager;
			
			if(null == manager.connection) throw new ArgumentError('SpodConnection required');
			_nativeSQLErrorEventSignal = new NativeSignal(	_manager.connection, 
															SQLErrorEvent.ERROR, 
															SQLErrorEvent
															);
			_nativeSQLErrorEventSignal.strict = false;
			_nativeSQLEventSchemaSignal = new NativeSignal(	_manager.connection,
															SQLEvent.SCHEMA,
															SQLEvent
															);
			_nativeSQLEventSchemaSignal.strict = false;
			
			_tables = new Dictionary();
		}
		
		public function createTable(type : Class) : void
		{
			if(null == type) throw new ArgumentError('Type can not be null');
			
			if(!active(type))
			{
				const params : Array = [type];
				_nativeSQLErrorEventSignal.addWithPriority(	handleSQLErrorEventSignal, 
															int.MAX_VALUE
															).params = params;
				_nativeSQLEventSchemaSignal.addWithPriority(	handleSQLEventSchemaSignal
																).params = params;
				
				const name : String = getClassNameFromQname(getQualifiedClassName(type));
				_manager.connection.loadSchema(SQLTableSchema, name);
			}
			else throw new ArgumentError('Table already exists and is active, so you can not ' + 
																				'create it again');
		}
				
		public function active(type : Class) : Boolean
		{
			return null != _tables[type];
		}
		
		public function getTable(type : Class) : SpodTable
		{
			return active(type) ? _tables[type] : null; 
		}
		
		public function buildSchemaFromType(type : Class) : SpodTableSchema
		{
			if(null == type) throw new ArgumentError('Type can not be null');
			
			const description : XML = describeType(type);
			const tableName : String = getClassNameFromQname(description.@name);
			
			const schema : SpodTableSchema = new SpodTableSchema(type, tableName);
			
			for each(var parameter : XML in description..constructor.parameter)
			{
				if(parameter.@optional != 'true') 
					throw new ArgumentError('Type constructor parameters need to be optional');
			}
			
			var identifierFound : Boolean = false;
			for each(var variable : XML in description..variable)
			{
				const variableName : String = variable.@name;
				const variableType : String = variable.@type;
				
				if(variableName == 'id') identifierFound = true;
				
				schema.createByType(variableName, variableType);
			}
			
			const spodObjectQName : String = getQualifiedClassName(SpodObject);
			
			for each(var accessor : XML in description.factory.accessor)
			{
				const accessorName : String = accessor.@name;
				const accessorType : String = accessor.@type;
				
				if(accessor.@declaredBy == spodObjectQName) continue;
				if(accessor.@access != 'readwrite') 
				{
					throw new ArgumentError('Accessor (getter & setter) needs to be \'readwrite\'' +
																	' to work with SQLStatement');
				}
				
				if(accessorName == 'id') identifierFound = true;
				
				if(!schema.contains(accessorName)) schema.createByType(accessorName, accessorType);
			}
			
			if(!identifierFound) throw new ArgumentError('Type needs id variable to work');
			
			if(schema.columns.length == 0) throw new IllegalOperationError('Schema has no columns');
			
			return schema;
		}
		
		/**
		 * @private
		 */
		private function internalCreateTable(schema : SpodTableSchema) : void
		{
			if(null == schema) throw new ArgumentError('Schema can not be null');
			
			const builder : ISpodStatementBuilder = new CreateStatementBuilder(schema);
			const statement : SpodStatement = builder.build();
			
			if(null == statement) 
				throw new IllegalOperationError('SpodStatement can not be null');
			
			_tables[schema.type] = new SpodTable(schema, _manager);
			
			statement.completedSignal.add(handleCreateTableCompleteSignal);
			statement.errorSignal.add(handleCreateTableErrorSignal);
			
			_manager.executioner.add(statement);
		}
		
		/**
		 * @private
		 */
		private function handleSQLErrorEventSignal(event : SQLErrorEvent, type : Class) : void
		{
			// Catch the database not found error, if anything else we just let it slip through!
			if(event.errorID == 3115 && event.error.detailID == 1007)
			{
				event.stopImmediatePropagation();
				
				_nativeSQLErrorEventSignal.remove(handleSQLErrorEventSignal);
				_nativeSQLEventSchemaSignal.remove(handleSQLEventSchemaSignal);
				
				if(null == type) throw new IllegalOperationError('Type can not be null');
				
				const schema : SpodTableSchema = buildSchemaFromType(type);
				if(null == schema) throw new IllegalOperationError('Schema can not be null');
				
				// Create it because it doesn't exist
				internalCreateTable(schema);
			}
		}
		
		/**
		 * @private
		 */
		private function handleSQLEventSchemaSignal(event : SQLEvent, type : Class) : void
		{
			// This works out if there is a need to migrate a database or not!
			const schema : SpodTableSchema = buildSchemaFromType(type);
			if(null == schema) throw new IllegalOperationError('Schema can not be null');
			
			const result : SQLSchemaResult = _manager.connection.getSchemaResult();
			if(null == result || null == result.tables) internalCreateTable(schema);
			else
			{
				const tables : Array = result.tables;
				const total : int = tables.length;
				 
				if(total == 0) internalCreateTable(schema);
				else if(total == 1)
				{
					const sqlTable : SQLTableSchema = result.tables[0];
					if(schema.name != sqlTable.name)
					{
						throw new SpodError('Unexpected table name, expected ' + schema.name + 
																		' got ' + sqlTable.name);
					}
					
					const numColumns : int = schema.columns.length; 
					
					if(sqlTable.columns.length != numColumns)
					{
						throw new SpodError('Invalid column count, expected ' + numColumns + 
																' got ' + sqlTable.columns.length);
					}
					else
					{
						// This validates the schema of the database and the class!
						for(var i : int = 0; i<numColumns; i++)
						{
							const sqlColumnSchema : SQLColumnSchema = sqlTable.columns[i];
							const sqlColumnName : String = sqlColumnSchema.name;
							const sqlDataType : String = sqlColumnSchema.dataType;
							
							var match : Boolean = false;
							
							var index : int = numColumns;
							while(--index > -1)
							{
								const column : SpodTableColumnSchema = schema.columns[index];
								const dataType : String = SpodTypes.getSQLName(column.type);
								if(column.name == sqlColumnName && sqlDataType == dataType)
								{
									match = true;
								}
							}
							
							if(!match) 
							{
								throw new SpodError('Invalid table schema, expected ' + 
											schema.columns[i].name + ' and ' + 
											SpodTypes.getSQLName(schema.columns[i].type) + ' got ' +
											sqlColumnName + ' and ' + sqlDataType
											);
							}
						}
						
						// We don't need to make a new table as we've already got one!
						const table : SpodTable = new SpodTable(schema, _manager);
						
						_tables[type] = table;
						
						createTableSignal.dispatch(table);
					}
				}
				else throw new SpodError('Invalid table count, expected 1 got ' + total);
			}
		}
		
		/**
		 * @private
		 */
		private function handleCreateTableCompleteSignal(statement : SpodStatement) : void
		{
			statement.completedSignal.remove(handleCreateTableCompleteSignal);
			statement.errorSignal.remove(handleCreateTableErrorSignal);
			
			const table : SpodTable = _tables[statement.type];
			if(null == table) throw new IllegalOperationError('SpodTable does not exist');
			
			createTableSignal.dispatch(table);
		}
		
		/**
		 * @private
		 */
		private function handleCreateTableErrorSignal(	statement : SpodStatement, 
													event : SpodErrorEvent
													) : void
		{
			statement.completedSignal.remove(handleCreateTableCompleteSignal);
			statement.errorSignal.remove(handleCreateTableErrorSignal);
			
			_manager.errorSignal.dispatch(event);
		}
		
		public function get createTableSignal() : ISignal
		{
			if(null == _createTableSignal) _createTableSignal = new Signal(SpodTable);
			return _createTableSignal;
		}
	}
}
