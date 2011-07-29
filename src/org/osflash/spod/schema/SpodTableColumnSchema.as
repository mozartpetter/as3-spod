package org.osflash.spod.schema
{
	import org.osflash.spod.errors.SpodError;
	import org.osflash.spod.schema.types.SpodSchemaType;
	import org.osflash.spod.types.SpodTypes;
	/**
	 * @author Simon Richardson - simon@ustwo.co.uk
	 */
	public class SpodTableColumnSchema implements ISpodSchema
	{
		
		/**
		 * @private
		 */
		private var _name : String;
		
		/**
		 * @private
		 */
		private var _type : int;
		
		/**
		 * @private
		 */
		private var _autoIncrement : Boolean;

		public function SpodTableColumnSchema(name : String, type : int)
		{
			if(null == name) throw new ArgumentError('Name can not be null');
			if(name.length < 1) throw new ArgumentError('Name can not be emtpy');
			if(isNaN(type)) throw new ArgumentError('Type can not be NaN');
			if(!SpodTypes.valid(type)) throw new ArgumentError('Type is not a valid type');
			
			_name = name;
			_type = type;
			
			_autoIncrement = false;
		}

		public function get name() : String { return _name; }
		
		public function get identifier() : String { return _name; }

		public function get type() : int { return _type; }
		
		public function get autoIncrement() : Boolean { return _autoIncrement; }
		
		public function set autoIncrement(value : Boolean) : void 
		{ 
			// TODO : don't allow if the table has already been created, or if it has been provide
			// away to update the table.
			if(type == SpodTypes.INT || type == SpodTypes.UINT || type == SpodTypes.NUMBER)
				_autoIncrement = value;
			else throw new SpodError('Unable to autoIncrement on an invalid type');
		}
		
		public function get schemaType() : SpodSchemaType { return SpodSchemaType.TABLE_COLUMN; }
	}
}
