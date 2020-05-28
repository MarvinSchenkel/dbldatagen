# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
This module defines the DataAnalyzer class. This is still a work in progress.
"""
from pyspark.sql.types import StructField
from pyspark.sql.functions import expr, lit
from pyspark.sql import functions as fns


class DataAnalyzer:
    """ Class for data set generation """

    def __init__(self, df, sparkSession=None):
        """ Constructor:
        name is name of data set
        rows = amount of rows to generate
        seed = seed for random number generator
        partitions = number of partitions to generate
        """
        self.rowCount = 0
        self.schema = None
        self.df = df.cache()
        # assert sparkSession is not None, "The spark session attribute must be initialized"
        # self.sparkSession = sparkSession
        # if sparkSession is None:
        #    raise Exception("""ERROR: spark session not initialized
        #
        #            The spark session attribute must be initialized in the DataGenerator initialization
        #
        #            i.e DataGenerator(sparkSession=spark, name="test", ...)
        #            """)

    def lookup_field_type(self, typ):
        type_mappings = {
            "LongType": "Long",
            "IntegerType": "Int",
            "TimestampType": "Timestamp",
            "FloatType": "Float",
            "StringType": "String",
        }

        if typ in type_mappings:
            return type_mappings[typ]
        else:
            return typ

    def summarize_field(self, field):
        if isinstance(field, StructField):
            return "{} {}".format(field.name, self.lookup_field_type(str(field.dataType)))
        else:
            return str(field)

    def summarize_fields(self, schema):
        if schema is not None:
            fields = schema.fields
            fields_desc = [self.summarize_field(x) for x in fields]
            return "Record(" + ",".join(fields_desc) + ")"
        else:
            return "N/A"

    def field_names(self, schema):
        """ get field names from schema"""
        if schema is not None and schema.fields is not None:
            return [x.name for x in schema.fields if isinstance(x, StructField)]
        else:
            return []

    def get_distinct_counts(self):
        pass

    def display_row(self, row):
        results = []
        row_key_pairs = row.asDict()
        for x in row_key_pairs:
            results.append("{}: {}".format(str(x), str(row[x])))

        return ", ".join(results)

    def prepend_summary(self, df, heading):
        field_names = self.field_names(self.df.schema)
        select_fields = ["summary"]
        select_fields.extend(field_names)

        return (df.withColumn("summary", lit(heading))
                .select(*select_fields))

    def summarize(self):
        count = self.df.count()
        distinct_count = self.df.distinct().count()
        partition_count = self.df.rdd.getNumPartitions()

        results = []
        summary = """
           count: {}
           distinct count: {}
           partition count: {} 
        """.format(count, distinct_count, partition_count)

        results.append(summary)
        results.append("schema: " + self.summarize_fields(self.df.schema))

        field_names = self.field_names(self.df.schema)
        select_fields = ["summary"]
        select_fields.extend(field_names)
        #        print("select fields:", select_fields)
        #        print("field names", field_names)
        distinct_expressions = [fns.countDistinct(x).alias(x) for x in self.field_names(self.df.schema)]
        results.append(self.display_row(
            self.prepend_summary(self.df.agg(*distinct_expressions),
                                 'distinct_count')
                .select(*select_fields)
                .collect()[0]
        ))

        for r in self.df.describe().collect():
            results.append(self.display_row(r))

        return "\n".join([str(x) for x in results])