""" This creates the json that can be used to create an new EntitySchema. 
	@see https://typeorm.io/separating-entity-definition
"""



# hack since code is not a package yet.
import sys
import os
sys.path.insert(1, os.path.join(sys.path[0], '..'))

from factory import ClassFactory
from pprint import pprint
from pathlib import Path
import pandas as pd
import ast
import json
import os
import re

def enums_to_string(cls):
	""" Generates the contents of a typeorm typescript file defining all enum datatypes in the ontology. """
	# Enums could also be defined inline I believe, but then they wouldn't (?) be accessible elsewhere.
	def string_to_python_variable(s):  # https://stackoverflow.com/questions/3303312/how-do-i-convert-a-string-to-a-valid-variable-name-in-python
		s = re.sub('[^0-9a-zA-Z_]', '', s)  # Remove invalid characters
		s = re.sub('^[^a-zA-Z_]+', '', s)   # Remove leading characters until we find a letter or underscore
		return s
	string = ""
	for name, values in cls.DATATYPES.items():
		string = f"export enum {name.replace('.', '_')} {{"
		for value in values:
			variable_name = string_to_python_variable(value)
			string += "\n\t" + f'{variable_name} = "{value}"'
		string += "\n}"
	return string

def create_typeorm(ontology_entity):
	# Note that this returns a json, so that it can be edited.
	# Column options (eg: nullable) is a buisness/technical decision and are therefore not
	# part of the ontology. Instead, the caller should modify the returned json.

	# TODO: In Protege, stop using xsd and create "vs" datatypes and all data properties
	# should be from this. We can assert this on compilation. Furthermore, we can assert
	# that each vs:datatype has a conversion here.

	# https://github.com/typeorm/typeorm/blob/master/docs/entities.md#user-content-column-types
	type_mapping = {
		"<class 'str'>": "String",
		"<class 'int'>": "Int",
		"<class 'bool'>": "Boolean"
	}
	
	typeorm = {}
	typeorm["name"] = ontology_entity["Name"].split('.')[-1]
	typeorm["columns"] = {
		"id": {
            "type": "String",
            "primary": True,
            "generated": True,
        }
	}
	typeorm["relations"] = {}

	for op in ontology_entity["Relations"]:
		op_name = op["Name"].split('.')[-1]
		
		# Assert that there is only one value for the range. Supporting "or" is future work.
		op_range = op["Range"]
		try:
			assert len(op_range) == 1, (typeorm["name"], op_name, op_range)
			assert len(op_range[0]) == 1, (typeorm["name"], op_name, op_range)
			op_range = op_range[0][0]
			assert op_range.split('.')[-1] == "Person"


			print(op["Range"])
			typeorm["relations"][op_name] = {
				"type": "many-to-many",
				"target": op_range.split('.')[-1],
			}
		except AssertionError:
			pass
		
		print(typeorm["name"], op_name)

	for op in ontology_entity["Data"]:
		op_name = op["Name"].split('.')[-1]
		
		# Rename data types (this may change if custom vs:datatypes are defined)
		op_range = str(op["Range"])
		for f, t in type_mapping.items():
			op_range = op_range.replace(f, t)
		op_range = ast.literal_eval(op_range)

		# Assert that there is only one value for the range. Supporting "or" is future work.
		assert len(op_range) == 1, (typeorm["name"], op_name, op_range)
		assert len(op_range[0]) == 1, (typeorm["name"], op_name, op_range)
		op_range = op_range[0][0]
		
		if op_range in ClassFactory.DATATYPES:  # Enum
			typeorm["columns"][op_name] = {  # How to inject a default value?
				"type": 'enum',
				"enum": op_range.replace('.', '_'),
			}
		else:
			typeorm["columns"][op_name] = {
				"type": op_range,
			}

	return typeorm

if __name__ == '__main__':
	from pprint import pprint
	print("Enums can be exported from the ontology to typeorm.")
	print(enums_to_string(ClassFactory))
	print()

	print("The Person class can be represented in typeorm json:")
	pprint(create_typeorm(ClassFactory.CLASSES["person.Person"]))
	x = """\
	import { EntitySchema } from "typeorm"
	export const person_Person = new EntitySchema(
		ClassFactory.create_typeorm(JSON["person.Person"])
	)
	"""
	print("This could be used like this:")
	print(x)

