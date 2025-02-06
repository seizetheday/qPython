.. _type-conversion:

Types conversions
=================


Data types supported by q and Python are incompatible and thus require 
additional translation. This page describes default rules used for converting 
data types between q and Python.

The translation mechanism used in qPython library is designed to:
 - deserialized message from kdb+ can be serialized and send back to kdb+ 
   without additional processing,
 - end user can enforce type hinting for translation,
 - efficient storage for tables and lists is backed with numpy arrays.

Default type mapping can be overriden by using custom IPC serializers
or deserializers implementations.

Atoms
***** 

While parsing IPC message atom q types are translated to Python types according
to this table:

===============  ============ =====================================
 q  type          q num type   Python type        
===============  ============ =====================================
 ``bool``         -1           ``numpy.bool_``
 ``guid``         -2           ``UUID``
 ``byte``         -4           ``numpy.byte``
 ``short``        -5           ``numpy.int16``
 ``integer``      -6           ``numpy.int32``
 ``long``         -7           ``numpy.int64``
 ``real``         -8           ``numpy.float32``
 ``float``        -9           ``numpy.float64``
 ``character``    -10          single element ``str``
 ``timestamp``    -12          ``QTemporal  numpy.datetime64   ns``
 ``month``        -13          ``QTemporal  numpy.datetime64   M``
 ``date``         -14          ``QTemporal  numpy.datetime64   D``
 ``datetime``     -15          ``QTemporal  numpy.datetime64   ms``
 ``timespan``     -16          ``QTemporal  numpy.timedelta64  ns``
 ``minute``       -17          ``QTemporal  numpy.timedelta64  m``
 ``second``       -18          ``QTemporal  numpy.timedelta64  s``
 ``time``         -19          ``QTemporal  numpy.timedelta64  ms``
===============  ============ =====================================

.. note:: By default, temporal types in Python are represented as instances of 
          :class:`.qtemporal.QTemporal` wrapping over ``numpy.datetime64`` or
          ``numpy.timedelta64`` with specified resolution.
          This setting can be modified (`numpy_temporals = True`) and temporal
          types can be represented without wrapping.


During the serialization to IPC protocol, Python types are mapped to q as 
described in the table:

=====================================  ================  ============
 Python type                            q type            q num type 
=====================================  ================  ============
 ``bool``                               ``bool``          -1
 ---                                    ``byte``          -4
 ---                                    ``short``         -5
 ``int``                                ``int``           -6
 ``long``                               ``long``          -7
 ---                                    ``real``          -8
 ``double``                             ``float``         -9
 ``numpy.bool``                         ``bool``          -1
 ``numpy.byte``                         ``byte``          -4
 ``numpy.int16``                        ``short``         -5
 ``numpy.int32``                        ``int``           -6
 ``numpy.int64``                        ``long``          -7
 ``numpy.float32``                      ``real``          -8
 ``numpy.float64``                      ``float``         -9
 single element ``str``                 ``character``     -10
 ``QTemporal  numpy.datetime64   ns``   ``timestamp``     -12
 ``QTemporal  numpy.datetime64   M``    ``month``         -13
 ``QTemporal  numpy.datetime64   D``    ``date``          -14
 ``QTemporal  numpy.datetime64   ms``   ``datetime``      -15
 ``QTemporal  numpy.timedelta64  ns``   ``timespan``      -16
 ``QTemporal  numpy.timedelta64  m``    ``minute``        -17
 ``QTemporal  numpy.timedelta64  s``    ``second``        -18
 ``QTemporal  numpy.timedelta64  ms``   ``time``          -19
=====================================  ================  ============

.. note:: By default, single element strings are serialized as q characters. 
          This setting can be modified (`single_char_strings = True`) and 
          and single element strings are represented as q strings.


String and symbols
******************

In order to distinguish symbols and strings on the Python side, following rules 
apply:

- q symbols are represented as ``numpy.bytes_`` type,
- q strings are mapped to plain Python strings in Python 2 and ``bytes`` in Python 3.

::

    # Python 2
    # `quickbrownfoxjumpsoveralazydog
    <type 'numpy.bytes_'>
    numpy.bytes_('quickbrownfoxjumpsoveralazydog')
    
    # "quick brown fox jumps over a lazy dog"
    <type 'str'>
    'quick brown fox jumps over a lazy dog'

    # Python 3
    # `quickbrownfoxjumpsoveralazydog
    <class 'numpy.bytes_'>
    b'quickbrownfoxjumpsoveralazydog'
    
    # "quick brown fox jumps over a lazy dog"
    <class 'bytes'>
    b'quick brown fox jumps over a lazy dog'


.. note:: By default, single element strings are serialized as q characters. 
          This setting can be modified (`single_char_strings = True`) and 
          and single element strings are represented as q strings.

::
          
    >>> # serialize single element strings as q characters 
    >>> print(q.sendSync('{[x] type each x}', ['one', 'two', '3'], single_char_strings = False))
    [ 10,  10, -10]
    
    >>> # serialize single element strings as q strings 
    >>> print(q.sendSync('{[x] type each x}', ['one', 'two', '3'], single_char_strings = True))
    [10, 10, 10]


Lists
*****

qPython represents deserialized q lists as instances of 
:class:`.qcollection.QList` are mapped to `numpy` arrays.

::

    # (0x01;0x02;0xff)
    qlist(numpy.array([0x01, 0x02, 0xff], dtype=numpy.byte))
    
    # <class 'qpython.qcollection.QList'> 
    # numpy.dtype: int8 
    # meta.qtype: -4
    # str: [ 1  2 -1]


Generic lists are represented as a plain Python lists.

::

    # (1;`bcd;"0bc";5.5e)
    [numpy.int64(1), numpy.bytes_('bcd'), '0bc', numpy.float32(5.5)]


While serializing Python data to q following heuristic is applied:

- instances of :class:`.qcollection.QList` and 
  :class:`.qcollection.QTemporalList` are serialized according to type indicator 
  (``meta.qtype``)::
  
    qlist([1, 2, 3], qtype = QSHORT_LIST)
    # (1h;2h;3h)
    
    qlist([366, 121, qnull(QDATE)], qtype=QDATE_LIST)
    # '2001.01.01 2000.05.01 0Nd'
    
    qlist(numpy.array([uuid.UUID('8c680a01-5a49-5aab-5a65-d4bfddb6a661'), qnull(QGUID)]), qtype=QGUID_LIST)
    # ("G"$"8c680a01-5a49-5aab-5a65-d4bfddb6a661"; 0Ng)
  
- `numpy` arrays are serialized according to type of their `dtype` value::
 
    numpy.array([1, 2, 3], dtype=numpy.int32)
    # (1i;2i;3i)
  
- if `numpy` array `dtype` is not recognized by qPython, result q type is 
  determined by type of the first element in the array,
- Python lists and tuples are represented as q generic lists::

    [numpy.int64(42), None, numpy.bytes_('foo')]
    (numpy.int64(42), None, numpy.bytes_('foo'))
    # (42;::;`foo)
    
.. note:: `numpy` arrays with ``dtype==|S1`` are represented as atom character.


qPython provides an utility function :func:`.qcollection.qlist` 
which simplifies creation of :class:`.qcollection.QList` and 
:class:`.qcollection.QTemporalList` instances.

The :py:mod:`.qtype` module defines :py:const:`~.qtype.QSTRING_LIST` const
which simplifies creation of string lists::

    qlist(numpy.array(['quick', 'brown', 'fox', 'jumps', 'over', 'a lazy', 'dog']), qtype = QSTRING_LIST)
    qlist(['quick', 'brown', 'fox', 'jumps', 'over', 'a lazy', 'dog'], qtype = QSTRING_LIST)
    ['quick', 'brown', 'fox', 'jumps', 'over', 'a lazy', 'dog']
    # ("quick"; "brown"; "fox"; "jumps"; "over"; "a lazy"; "dog")

.. note:: ``QSTRING_LIST`` type indicator indicates that list/array has to be
          mapped to q generic list. 


Temporal lists
++++++++++++++
          
By default, lists of temporal values are represented as instances of 
:class:`.qcollection.QTemporalList` class. This class wraps the raw q 
representation of temporal data (i.e. ``long``\s for ``timestamp``\s, ``int``\s 
for ``month``\s etc.) and provides accessors which allow to convert raw data to 
:class:`.qcollection.QTemporal` instances in a lazy fashion.

::

    >>> v = q.sendSync("2001.01.01 2000.05.01 0Nd", numpy_temporals = False)
    >>> print('%s dtype: %s qtype: %d: %s' % (type(v), v.dtype, v.meta.qtype, v))
    <class 'qpython.qcollection.QTemporalList'> dtype: int32 qtype: -14: [2001-01-01 [metadata(qtype=-14)] 2000-05-01 [metadata(qtype=-14)]
     NaT [metadata(qtype=-14)]]
    
    >>> v = q.sendSync("2000.01.04D05:36:57.600 0Np", numpy_temporals = False)
    >>> print('%s dtype: %s qtype: %d: %s' % (type(v), v.dtype, v.meta.qtype, v))
    <class 'qpython.qcollection.QTemporalList'> dtype: int64 qtype: -12: [2000-01-04T05:36:57.600000000+0100 [metadata(qtype=-12)]
     NaT [metadata(qtype=-12)]]


The IPC parser (:class:`.qreader.QReader`) can be instructed to represent the
temporal vectors via `numpy.datetime64` or `numpy.timedelta64` arrays wrapped in
:class:`.qcollection.QList` instances. The parsing option can be set either
via :class:`~.qconnection.QConnection` constructor or as parameter to functions:
(:meth:`~qpython.qconnection.QConnection.sendSync`) or 
(:meth:`~qpython.qconnection.QConnection.receive`).

::
    
    >>> v = q.sendSync("2001.01.01 2000.05.01 0Nd", numpy_temporals = True)
    >>> print('%s dtype: %s qtype: %d: %s' % (type(v), v.dtype, v.meta.qtype, v))
    <class 'qpython.qcollection.QList'> dtype: datetime64[D] qtype: -14: ['2001-01-01' '2000-05-01' 'NaT']
    
    >>> v = q.sendSync("2000.01.04D05:36:57.600 0Np", numpy_temporals = True)
    >>> print('%s dtype: %s qtype: %d: %s' % (type(v), v.dtype, v.meta.qtype, v))
    <class 'qpython.qcollection.QList'> dtype: datetime64[ns] qtype: -12: ['2000-01-04T05:36:57.600000000+0100' 'NaT']
    

In this parsing mode, temporal null values are converted to `numpy.NaT`.


The serialization mechanism (:class:`.qwriter.QWriter`) accepts both 
representations and doesn't require additional configuration.


There are two utility functions for conversions between both representations:
    
- The :func:`.qtemporal.array_to_raw_qtemporal` function simplifies adjusting
  of `numpy.datetime64` or `numpy.timedelta64` arrays to q representation as raw
  integer vectors.
- The :func:`.qtemporal.array_from_raw_qtemporal` converts raw temporal array
  to `numpy.datetime64` or `numpy.timedelta64` array.


Dictionaries
************

qPython represents q dictionaries with custom :class:`.qcollection.QDictionary` 
class.

Examples::

    QDictionary(qlist(numpy.array([1, 2], dtype=numpy.int64), qtype=QLONG_LIST), 
                qlist(numpy.array(['abc', 'cdefgh']), qtype = QSYMBOL_LIST))
    # q: 1 2!`abc`cdefgh
    
       
    QDictionary([numpy.int64(1), numpy.int16(2), numpy.float64(3.234), '4'], 
                [numpy.bytes_('one'), qlist(numpy.array([2, 3]), qtype=QLONG_LIST), '456', [numpy.int64(7), qlist(numpy.array([8, 9]), qtype=QLONG_LIST)]])
    # q: (1;2h;3.234;"4")!(`one;2 3;"456";(7;8 9))


The :class:`.qcollection.QDictionary` class implements Python collection API.
    
    
Tables
******

The q tables are translated into custom :class:`.qcollection.QTable` class. 

qPython provides an utility function :func:`.qcollection.qtable` which simplifies
creation of tables. This function also allow user to override default type
conversions for each column and provide explicit q type hinting per column.

Examples::

    qtable(qlist(numpy.array(['name', 'iq']), qtype = QSYMBOL_LIST), 
          [qlist(numpy.array(['Dent', 'Beeblebrox', 'Prefect'])), 
           qlist(numpy.array([98, 42, 126], dtype=numpy.int64))])
    
    qtable(qlist(numpy.array(['name', 'iq']), qtype = QSYMBOL_LIST),
          [qlist(['Dent', 'Beeblebrox', 'Prefect'], qtype = QSYMBOL_LIST), 
           qlist([98, 42, 126], qtype = QLONG_LIST)])
           
    qtable(['name', 'iq'],
           [['Dent', 'Beeblebrox', 'Prefect'], 
            [98, 42, 126]],
           name = QSYMBOL, iq = QLONG)       
    
    # flip `name`iq!(`Dent`Beeblebrox`Prefect;98 42 126)
    
    
    qtable(('name', 'iq', 'fullname'),
           [qlist(numpy.array(['Dent', 'Beeblebrox', 'Prefect']), qtype = QSYMBOL_LIST), 
            qlist(numpy.array([98, 42, 126]), qtype = QLONG_LIST),
            qlist(numpy.array(["Arthur Dent", "Zaphod Beeblebrox", "Ford Prefect"]), qtype = QSTRING_LIST)])
    
    # flip `name`iq`fullname!(`Dent`Beeblebrox`Prefect;98 42 126;("Arthur Dent"; "Zaphod Beeblebrox"; "Ford Prefect"))


The keyed tables are represented by :class:`.qcollection.QKeyedTable` instances,
where both keys and values are stored as a separate :class:`.qcollection.QTable` 
instances.

For example::

    # ([eid:1001 1002 1003] pos:`d1`d2`d3;dates:(2001.01.01;2000.05.01;0Nd))
    QKeyedTable(qtable(['eid'],
                       [qlist(numpy.array([1001, 1002, 1003]), qtype = QLONG_LIST)]),
                qtable(['pos', 'dates'],
                       [qlist(numpy.array(['d1', 'd2', 'd3']), qtype = QSYMBOL_LIST), 
                        qlist(numpy.array([366, 121, qnull(QDATE)]), qtype = QDATE_LIST)]))


Functions, lambdas and projections
**********************************

IPC protocol type codes 100+ are used to represent functions, lambdas and 
projections. These types are represented as instances of base class 
:class:`.qtype.QFunction` or descendent classes:

- :class:`.qtype.QLambda` - represents q lambda expression, note the expression  
  is required to be either:

    - q expression enclosed in {}, e.g.: ``{x + y}``
    - k expression, e.g.: ``k){x + y}``
 
- :class:`.qtype.QProjection` - represents function projection with parameters::
  
    # { x + y}[3]
    QProjection([QLambda('{x+y}'), numpy.int64(3)])

  
.. note:: Only :class:`.qtype.QLambda` and :class:`.qtype.QProjection` are 
          serializable. qPython doesn't provide means to serialize other 
          function types.


Errors
******

The q errors are represented as instances of :class:`.qtype.QException` class.


Null values
***********

Please note that q ``null`` values are defined as::

    _QNULL1 = numpy.int8(-2**7)
    _QNULL2 = numpy.int16(-2**15)
    _QNULL4 = numpy.int32(-2**31)
    _QNULL8 = numpy.int64(-2**63)
    _QNAN32 = numpy.frombuffer('\x00\x00\xc0\x7f', dtype=numpy.float32)[0]
    _QNAN64 = numpy.frombuffer('\x00\x00\x00\x00\x00\x00\xf8\x7f', dtype=numpy.float64)[0]
    _QNULL_BOOL = numpy.bool_(False)
    _QNULL_SYM = numpy.bytes_('')
    _QNULL_GUID = uuid.UUID('00000000-0000-0000-0000-000000000000')


Complete null mapping between q and Python is represented in the table:

============== ============== =======================
 q type         q null value   Python representation 
============== ============== =======================
 ``bool``       ``0b``          ``_QNULL_BOOL``
 ``guid``       ``0Ng``         ``_QNULL_GUID``
 ``byte``       ``0x00``        ``_QNULL1``
 ``short``      ``0Nh``         ``_QNULL2``
 ``int``        ``0N``          ``_QNULL4``
 ``long``       ``0Nj``         ``_QNULL8``
 ``real``       ``0Ne``         ``_QNAN32``
 ``float``      ``0n``          ``_QNAN64``
 ``string``     ``" "``         ``' '``
 ``symbol``     \`              ``_QNULL_SYM``
 ``timestamp``  ``0Np``         ``_QNULL8``
 ``month``      ``0Nm``         ``_QNULL4``
 ``date``       ``0Nd``         ``_QNULL4``
 ``datetime``   ``0Nz``         ``_QNAN64``
 ``timespan``   ``0Nn``         ``_QNULL8``
 ``minute``     ``0Nu``         ``_QNULL4``
 ``second``     ``0Nv``         ``_QNULL4``
 ``time``       ``0Nt``         ``_QNULL4``
============== ============== =======================

The :py:mod:`qtype` provides two utility functions to work with null values:

- :func:`~.qtype.qnull` - retrieves null type for specified q type code,
- :func:`~.qtype.is_null` - checks whether value is considered a null for
  specified q type code.


.. _custom_type_mapping:

Custom type mapping
*******************

Default type mapping can be overwritten by providing custom implementations
of :class:`.QWriter` and/or :class:`.QReader` and proper initialization of
the connection as described in :ref:`custom_ipc_mapping`. 

:class:`.QWriter` and :class:`.QReader` use parse time decorator 
(:class:`Mapper`) which generates mapping between q and Python types.
This mapping is stored in a static variable: ``QReader._reader_map`` and 
``QWriter._writer_map``. In case mapping is not found in the mapping:

- :class:`.QWriter` tries to find a matching qtype in the ``~qtype.Q_TYPE``
  dictionary and serialize data as q atom, 
- :class:`.QReader` tries to parse lists and atoms based on the type indicator
  in IPC stream.

While subclassing these classes, user can create copy of the mapping
in the parent class and use parse time decorator:


.. code:: python

    class PandasQWriter(QWriter):
        _writer_map = dict.copy(QWriter._writer_map)    # create copy of default serializer map
        serialize = Mapper(_writer_map)                 # upsert custom mapping
    
        @serialize(pandas.Series)
        def _write_pandas_series(self, data, qtype = None):
            # serialize pandas.Series into IPC stream
            # ..omitted for readability..
            self._write_list(data, qtype = qtype)
  

    class PandasQReader(QReader):
        _reader_map = dict.copy(QReader._reader_map)   # create copy of default deserializer map
        parse = Mapper(_reader_map)                    # overwrite default mapping
    
        @parse(QTABLE)
        def _read_table(self, qtype = QTABLE):
            # parse q table as pandas.DataFrame
            # ..omitted for readability..
            return pandas.DataFrame(data)

Refer to :ref:`sample_custom_reader` for complete example.